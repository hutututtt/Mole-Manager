package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
)

type statusSnapshot struct {
	Timestamp   time.Time     `json:"timestamp"`
	HealthScore int           `json:"healthScore"`
	CPU         usageTemp     `json:"cpu"`
	Memory      memorySummary `json:"memory"`
	Disk        diskSummary   `json:"disk"`
	Network     networkRate   `json:"network"`
}

type usageTemp struct {
	Usage float64 `json:"usage"`
	TempC float64 `json:"tempC"`
}

type memorySummary struct {
	UsedPercent float64 `json:"usedPercent"`
	UsedGB      float64 `json:"usedGB"`
	TotalGB     float64 `json:"totalGB"`
}

type diskSummary struct {
	UsedPercent float64 `json:"usedPercent"`
	FreeGB      float64 `json:"freeGB"`
}

type networkRate struct {
	DownMBps float64 `json:"downMBps"`
	UpMBps   float64 `json:"upMBps"`
}

type task struct {
	ID        string    `json:"id"`
	Type      string    `json:"type"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"createdAt"`
}

type createTaskRequest struct {
	Type string `json:"type"`
}

type taskStore struct {
	mu    sync.RWMutex
	tasks []task
}

func (s *taskStore) add(taskType string) task {
	s.mu.Lock()
	defer s.mu.Unlock()

	t := task{
		ID:        fmt.Sprintf("tsk_%d", time.Now().UnixNano()),
		Type:      taskType,
		Status:    "queued",
		CreatedAt: time.Now().UTC(),
	}
	s.tasks = append(s.tasks, t)
	return t
}

func (s *taskStore) list() []task {
	s.mu.RLock()
	defer s.mu.RUnlock()

	out := make([]task, len(s.tasks))
	copy(out, s.tasks)
	return out
}

func (s *taskStore) get(id string) (task, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	for _, t := range s.tasks {
		if t.ID == id {
			return t, true
		}
	}
	return task{}, false
}

type gatewayServer struct {
	store *taskStore
}

func newGatewayServer() *gatewayServer {
	return &gatewayServer{store: &taskStore{}}
}

func (g *gatewayServer) routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/health", g.handleHealth)
	mux.HandleFunc("/api/v1/status/snapshot", g.handleSnapshot)
	mux.HandleFunc("/api/v1/tasks", g.handleTasks)
	mux.HandleFunc("/api/v1/tasks/", g.handleTaskByID)
	return mux
}

func (g *gatewayServer) handleHealth(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (g *gatewayServer) handleSnapshot(w http.ResponseWriter, _ *http.Request) {
	snapshot := statusSnapshot{
		Timestamp:   time.Now().UTC(),
		HealthScore: 92,
		CPU:         usageTemp{Usage: 21.7, TempC: 55.3},
		Memory:      memorySummary{UsedPercent: 43.1, UsedGB: 13.8, TotalGB: 32},
		Disk:        diskSummary{UsedPercent: 61.3, FreeGB: 211.5},
		Network:     networkRate{DownMBps: 1.2, UpMBps: 0.18},
	}
	writeJSON(w, http.StatusOK, snapshot)
}

func (g *gatewayServer) handleTasks(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		writeJSON(w, http.StatusOK, map[string]any{"items": g.store.list()})
	case http.MethodPost:
		var req createTaskRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeJSON(w, http.StatusBadRequest, errorResponse("INVALID_ARGUMENT", "invalid json body"))
			return
		}
		req.Type = strings.TrimSpace(req.Type)
		if req.Type == "" {
			writeJSON(w, http.StatusBadRequest, errorResponse("INVALID_ARGUMENT", "type is required"))
			return
		}
		created := g.store.add(req.Type)
		writeJSON(w, http.StatusCreated, created)
	default:
		w.WriteHeader(http.StatusMethodNotAllowed)
	}
}

func (g *gatewayServer) handleTaskByID(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}
	id := strings.TrimPrefix(r.URL.Path, "/api/v1/tasks/")
	id = strings.TrimSpace(id)
	if id == "" {
		writeJSON(w, http.StatusNotFound, errorResponse("RESOURCE_NOT_FOUND", "task not found"))
		return
	}
	item, ok := g.store.get(id)
	if !ok {
		writeJSON(w, http.StatusNotFound, errorResponse("RESOURCE_NOT_FOUND", "task not found"))
		return
	}
	writeJSON(w, http.StatusOK, item)
}

func errorResponse(code string, message string) map[string]any {
	return map[string]any{"error": map[string]any{"code": code, "message": message}}
}

func writeJSON(w http.ResponseWriter, statusCode int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	_ = json.NewEncoder(w).Encode(v)
}

func main() {
	port := envInt("MOLE_GATEWAY_PORT", 17870)
	addr := ":" + strconv.Itoa(port)

	server := &http.Server{
		Addr:              addr,
		Handler:           newGatewayServer().routes(),
		ReadHeaderTimeout: 5 * time.Second,
	}

	go func() {
		log.Printf("mole gateway listening on %s", addr)
		if err := server.ListenAndServe(); !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("gateway failed: %v", err)
		}
	}()

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	<-sigCh

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_ = server.Shutdown(ctx)
}

func envInt(key string, fallback int) int {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}
	port, err := strconv.Atoi(value)
	if err != nil {
		return fallback
	}
	return port
}
