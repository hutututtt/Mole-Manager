package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHealthEndpoint(t *testing.T) {
	srv := newGatewayServer()
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rec := httptest.NewRecorder()

	srv.routes().ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rec.Code)
	}
}

func TestCreateAndGetTask(t *testing.T) {
	srv := newGatewayServer()

	body, _ := json.Marshal(map[string]string{"type": "clean:dry-run"})
	createReq := httptest.NewRequest(http.MethodPost, "/api/v1/tasks", bytes.NewReader(body))
	createRec := httptest.NewRecorder()
	srv.routes().ServeHTTP(createRec, createReq)

	if createRec.Code != http.StatusCreated {
		t.Fatalf("expected status 201, got %d", createRec.Code)
	}

	var created task
	if err := json.Unmarshal(createRec.Body.Bytes(), &created); err != nil {
		t.Fatalf("decode created task: %v", err)
	}
	if created.ID == "" {
		t.Fatalf("expected created task id")
	}

	getReq := httptest.NewRequest(http.MethodGet, "/api/v1/tasks/"+created.ID, nil)
	getRec := httptest.NewRecorder()
	srv.routes().ServeHTTP(getRec, getReq)

	if getRec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", getRec.Code)
	}
}

func TestCreateTaskRequiresType(t *testing.T) {
	srv := newGatewayServer()

	body, _ := json.Marshal(map[string]string{"type": ""})
	req := httptest.NewRequest(http.MethodPost, "/api/v1/tasks", bytes.NewReader(body))
	rec := httptest.NewRecorder()
	srv.routes().ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400, got %d", rec.Code)
	}
}
