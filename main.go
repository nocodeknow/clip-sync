//go:build windows

package main

import (
	"os"
	"os/exec"
	"os/signal"
	"syscall"
)

func main() {
	initLog()
	logMsg("ClipSync v2 starting")

	// Start UDP discovery beacon (broadcasts PC's IP every 3s)
	go startBeacon()

	// Start the WebSocket server in background
	go startServer()

	// Start the event-driven clipboard listener (runs its own OS-thread message loop)
	go runClipboardListener()

	// Block until the user/system sends SIGINT or SIGTERM
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, os.Interrupt, syscall.SIGTERM)
	<-quit

	logMsg("ClipSync shutting down")
	stopBeacon()
	stopClipboardListener()
	stopServer()
	logMsg("ClipSync stopped")
	closeLog()
}

// openFile opens a file path using the default Windows application.
// Used for opening the log file (kept for potential future use).
func openFile(path string) {
	exec.Command("cmd", "/c", "start", "", path).Start()
}
