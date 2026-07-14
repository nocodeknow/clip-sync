package main

import (
	"fmt"
	"net"
	"time"
)

const (
	beaconPort    = 54320
	beaconPayload = "CLIPSYNC:54321"
	beaconInterval = 3 * time.Second
)

var beaconStop = make(chan struct{})

// startBeacon broadcasts a UDP discovery packet every 3 seconds so Android
// clients can find this PC without any manual IP configuration.
func startBeacon() {
	addr, err := net.ResolveUDPAddr("udp4", fmt.Sprintf("255.255.255.255:%d", beaconPort))
	if err != nil {
		logMsg(fmt.Sprintf("beacon: failed to resolve broadcast addr: %v", err))
		return
	}

	conn, err := net.DialUDP("udp4", nil, addr)
	if err != nil {
		logMsg(fmt.Sprintf("beacon: failed to open UDP socket: %v", err))
		return
	}
	defer conn.Close()

	conn.SetWriteBuffer(512)

	payload := []byte(beaconPayload)
	logMsg(fmt.Sprintf("beacon: broadcasting '%s' every %s on port %d", beaconPayload, beaconInterval, beaconPort))

	ticker := time.NewTicker(beaconInterval)
	defer ticker.Stop()

	// Send one immediately on start so Android connects fast
	conn.Write(payload)

	for {
		select {
		case <-ticker.C:
			conn.Write(payload)
		case <-beaconStop:
			logMsg("beacon: stopped")
			return
		}
	}
}

func stopBeacon() {
	select {
	case beaconStop <- struct{}{}:
	default:
	}
}
