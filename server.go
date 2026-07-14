package main

import (
	"context"
	"fmt"
	"net/http"
	"sync"
	"time"

	"github.com/atotto/clipboard"
	"github.com/gorilla/websocket"
)

const (
	wsPort       = ":54321"
	pingInterval = 20 * time.Second
	pingTimeout  = 10 * time.Second
)

var (
	clients    = make(map[*wsClient]bool)
	clientsMu  sync.Mutex
	lastClip   string
	lastClipMu sync.Mutex
	httpServer *http.Server
)

// ── WebSocket client ──────────────────────────────────────────────────────────

type wsClient struct {
	conn *websocket.Conn
	send chan string
}

func (c *wsClient) write(msg string) {
	select {
	case c.send <- msg:
	default:
	}
}

func (c *wsClient) writePump() {
	ticker := time.NewTicker(pingInterval)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()
	for {
		select {
		case msg, ok := <-c.send:
			if !ok {
				return
			}
			c.conn.SetWriteDeadline(time.Now().Add(pingTimeout))
			if err := c.conn.WriteMessage(websocket.TextMessage, []byte(msg)); err != nil {
				return
			}
		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(pingTimeout))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

func (c *wsClient) readPump() {
	defer func() {
		clientsMu.Lock()
		delete(clients, c)
		n := len(clients)
		clientsMu.Unlock()
		c.conn.Close()
		logMsg(fmt.Sprintf("client disconnected (%d connected)", n))
	}()

	c.conn.SetReadDeadline(time.Now().Add(pingInterval + pingTimeout))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(pingInterval + pingTimeout))
		return nil
	})

	for {
		_, msg, err := c.conn.ReadMessage()
		if err != nil {
			return
		}
		text := string(msg)
		if text == "" {
			continue
		}

		lastClipMu.Lock()
		changed := text != lastClip
		if changed {
			lastClip = text
		}
		lastClipMu.Unlock()

		if changed {
			if err := clipboard.WriteAll(text); err != nil {
				logMsg(fmt.Sprintf("clipboard write error: %v", err))
			} else {
				logMsg(fmt.Sprintf("← android→windows (%d chars)", len(text)))
			}
		}
	}
}

// ── WebSocket server ──────────────────────────────────────────────────────────

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

func wsHandler(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		logMsg(fmt.Sprintf("upgrade error: %v", err))
		return
	}

	client := &wsClient{conn: conn, send: make(chan string, 8)}

	clientsMu.Lock()
	clients[client] = true
	n := len(clients)
	clientsMu.Unlock()

	logMsg(fmt.Sprintf("client connected: %s (%d connected)", r.RemoteAddr, n))

	// Send current clipboard text immediately on connect
	lastClipMu.Lock()
	cur := lastClip
	lastClipMu.Unlock()
	if cur != "" {
		client.write(cur)
	}

	go client.writePump()
	client.readPump() // blocks until disconnect
}

func startServer() {
	mux := http.NewServeMux()
	mux.HandleFunc("/", wsHandler)
	httpServer = &http.Server{Addr: wsPort, Handler: mux}
	logMsg("WebSocket server listening on ws://0.0.0.0" + wsPort)
	if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		logMsg(fmt.Sprintf("server error: %v", err))
	}
}

func stopServer() {
	if httpServer == nil {
		return
	}
	// Close all clients
	clientsMu.Lock()
	for c := range clients {
		c.conn.Close()
	}
	clients = make(map[*wsClient]bool)
	clientsMu.Unlock()

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	httpServer.Shutdown(ctx)
}

// broadcastToClients sends text to all connected Android clients.
// Called by the clipboard listener when Windows clipboard changes.
func broadcastToClients(text string) {
	clientsMu.Lock()
	defer clientsMu.Unlock()
	if len(clients) == 0 {
		return
	}
	logMsg(fmt.Sprintf("→ windows→android (%d chars)", len(text)))
	for c := range clients {
		c.write(text)
	}
}
