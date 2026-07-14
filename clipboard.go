//go:build windows

package main

import (
	"runtime"
	"syscall"
	"unsafe"

	"github.com/atotto/clipboard"
)

// Windows message constants
const (
	wmClipboardUpdate = 0x031D
	wmDestroy         = 0x0002
)

// HWND_MESSAGE = (HWND)-3 — a message-only window, invisible, no taskbar entry
const hwndMessage = ^uintptr(2)

var (
	user32   = syscall.NewLazyDLL("user32.dll")
	kernel32 = syscall.NewLazyDLL("kernel32.dll")

	procRegisterClassExW              = user32.NewProc("RegisterClassExW")
	procCreateWindowExW               = user32.NewProc("CreateWindowExW")
	procDestroyWindow                 = user32.NewProc("DestroyWindow")
	procGetMessageW                   = user32.NewProc("GetMessageW")
	procTranslateMessage              = user32.NewProc("TranslateMessage")
	procDispatchMessageW              = user32.NewProc("DispatchMessageW")
	procDefWindowProcW                = user32.NewProc("DefWindowProcW")
	procAddClipboardFormatListener    = user32.NewProc("AddClipboardFormatListener")
	procRemoveClipboardFormatListener = user32.NewProc("RemoveClipboardFormatListener")
	procPostQuitMessage               = user32.NewProc("PostQuitMessage")
	procPostMessageW                  = user32.NewProc("PostMessageW")
	procGetModuleHandleW              = kernel32.NewProc("GetModuleHandleW")
)

// WNDCLASSEXW mirrors the Win32 WNDCLASSEXW struct.
type wndClassExW struct {
	cbSize        uint32
	style         uint32
	lpfnWndProc   uintptr
	cbClsExtra    int32
	cbWndExtra    int32
	hInstance     uintptr
	hIcon         uintptr
	hCursor       uintptr
	hbrBackground uintptr
	lpszMenuName  *uint16
	lpszClassName *uint16
	hIconSm       uintptr
}

// MSG mirrors the Win32 MSG struct.
type tagMSG struct {
	hwnd    uintptr
	message uint32
	wParam  uintptr
	lParam  uintptr
	time    uint32
	pt      struct{ x, y int32 }
}

// clipListenerHwnd holds the handle of the message-only window.
var clipListenerHwnd uintptr

// wndProc is the window procedure for our hidden message-only window.
// It is called by Windows on every message dispatched to this window.
func wndProc(hwnd uintptr, msg uint32, wParam, lParam uintptr) uintptr {
	switch msg {
	case wmClipboardUpdate:
		// Clipboard changed — read the new text and broadcast if it differs
		text, err := clipboard.ReadAll()
		if err != nil || text == "" {
			return 0
		}
		lastClipMu.Lock()
		changed := text != lastClip
		if changed {
			lastClip = text
		}
		lastClipMu.Unlock()
		if changed {
			broadcastToClients(text)
		}
		return 0

	case wmDestroy:
		procPostQuitMessage.Call(0)
		return 0
	}

	ret, _, _ := procDefWindowProcW.Call(hwnd, uintptr(msg), wParam, lParam)
	return ret
}

// stopClipboardListener signals the message loop to exit cleanly.
func stopClipboardListener() {
	if clipListenerHwnd != 0 {
		procPostMessageW.Call(clipListenerHwnd, wmDestroy, 0, 0)
	}
}

// runClipboardListener creates a hidden message-only window, registers it as a
// clipboard format listener, and pumps Windows messages until the app exits.
//
// Must run on its own goroutine. Locks the OS thread because Windows message
// loops are thread-affine (the window and the loop must be on the same thread).
func runClipboardListener() {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	hInst, _, _ := procGetModuleHandleW.Call(0)

	className, _ := syscall.UTF16PtrFromString("ClipSyncMsgWnd")
	cb := syscall.NewCallback(wndProc)

	wc := wndClassExW{
		lpfnWndProc:   cb,
		lpszClassName: className,
		hInstance:     hInst,
	}
	wc.cbSize = uint32(unsafe.Sizeof(wc))

	if ret, _, _ := procRegisterClassExW.Call(uintptr(unsafe.Pointer(&wc))); ret == 0 {
		logMsg("ERROR: RegisterClassExW failed — clipboard listener not started")
		return
	}

	hwnd, _, _ := procCreateWindowExW.Call(
		0,                                  // dwExStyle
		uintptr(unsafe.Pointer(className)), // lpClassName
		0,                                  // lpWindowName  (no title)
		0,                                  // dwStyle
		0, 0, 0, 0,                         // x, y, width, height
		hwndMessage,                        // hWndParent = HWND_MESSAGE (message-only)
		0,                                  // hMenu
		hInst,                              // hInstance
		0,                                  // lpParam
	)
	if hwnd == 0 {
		logMsg("ERROR: CreateWindowExW failed — clipboard listener not started")
		return
	}
	clipListenerHwnd = hwnd

	if ret, _, _ := procAddClipboardFormatListener.Call(hwnd); ret == 0 {
		logMsg("ERROR: AddClipboardFormatListener failed")
		procDestroyWindow.Call(hwnd)
		return
	}

	logMsg("clipboard listener ready (event-driven)")

	// Seed the initial clipboard value so we don't broadcast stale content on
	// the first real change.
	if text, err := clipboard.ReadAll(); err == nil && text != "" {
		lastClipMu.Lock()
		lastClip = text
		lastClipMu.Unlock()
	}

	// Windows message loop — blocks here until WM_QUIT is posted.
	var m tagMSG
	for {
		r, _, _ := procGetMessageW.Call(uintptr(unsafe.Pointer(&m)), 0, 0, 0)
		if r == 0 || r == ^uintptr(0) { // 0 = WM_QUIT, ^0 = error
			break
		}
		procTranslateMessage.Call(uintptr(unsafe.Pointer(&m)))
		procDispatchMessageW.Call(uintptr(unsafe.Pointer(&m)))
	}

	procRemoveClipboardFormatListener.Call(hwnd)
	procDestroyWindow.Call(hwnd)
	logMsg("clipboard listener stopped")
}
