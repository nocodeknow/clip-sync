package main

import (
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"
)

var (
	logFile *os.File
	logMu   sync.Mutex
)

func initLog() {
	exe, err := os.Executable()
	if err != nil {
		return
	}
	dir := filepath.Dir(exe)
	path := filepath.Join(dir, "clipsync.log")
	f, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err == nil {
		logFile = f
	}
}

func logMsg(msg string) {
	line := fmt.Sprintf("%s  %s\n", time.Now().Format("2006-01-02 15:04:05"), msg)
	logMu.Lock()
	defer logMu.Unlock()
	if logFile != nil {
		logFile.WriteString(line)
	}
}

func closeLog() {
	logMu.Lock()
	defer logMu.Unlock()
	if logFile != nil {
		logFile.Close()
		logFile = nil
	}
}
