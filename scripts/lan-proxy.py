#!/usr/bin/env python3
"""Minecraft Bedrock LAN Proxy -- makes remote BDS servers appear as LAN games.

Sends periodic fake LAN discovery broadcast packets on port 19132 so that
Minecraft's Friends tab shows the server under "LAN Games". Also proxies
the actual game traffic between the client and remote server.

Usage:
    python3 lan-proxy.py <server-ip>:<server-port>:<local-port>:<name> [...]

Example:
    python3 lan-proxy.py 100.71.19.39:19132:19132:"Mellody Ann Brown" 100.71.19.39:8888:8888:donkey 100.71.19.39:8890:8890:Luna
"""
import argparse
import signal
import socket
import struct
import threading
import time

# Bedrock protocol constants
MAGIC = bytes.fromhex("00ffff00fefefefefdfdfdfd12345678")
UNCONNECTED_PONG_ID = b"\x1c"

# How long before cleaning up a client that stopped sending packets
CLIENT_TIMEOUT = 120  # seconds

# How often to check for stale clients (avoid checking on every packet)
CLEANUP_INTERVAL = 30  # seconds

# Ephemeral ports used by the broadcast socket, so the proxy can ignore
# packets that came from our own broadcaster.  Populated by broadcast_lan().
_broadcast_ports = set()


def build_pong_packet(server_name, server_port, server_guid=12345678901234567,
                      motd="Dedicated Server", gamemode="Creative",
                      players=0, max_players=10):
    """Build a fake unconnected pong packet that Minecraft uses for LAN discovery."""
    # Edition;MOTD;Protocol;Version;Players;MaxPlayers;ServerID;WorldName;Gamemode;NintendoLimited;Port;PortV6
    edition = "MCPE"
    # Protocol version shown in the LAN discovery UI.  The actual connection
    # negotiates its own version, so these don't need to match exactly.
    protocol = "776"
    version = "1.21.51"
    nintendo = "1"
    portv6 = str(server_port + 1)

    status = (f"{edition};{motd};{protocol};{version};{players};{max_players};"
              f"{server_guid};{server_name};{gamemode};{nintendo};{server_port};{portv6}")
    status_bytes = status.encode("utf-8")

    # Packet: ID (1) + Time (8) + ServerGUID (8) + Magic (16) + StringLength (2) + String
    packet = UNCONNECTED_PONG_ID
    packet += struct.pack(">q", int(time.time() * 1000))  # timestamp
    packet += struct.pack(">q", server_guid)               # server GUID
    packet += MAGIC
    packet += struct.pack(">H", len(status_bytes))
    packet += status_bytes
    return packet


def broadcast_lan(servers, interval=1.5):
    """Broadcast fake LAN discovery packets for all servers."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

    # Bind to an ephemeral port so we can identify self-sent packets in the proxy.
    sock.bind(("", 0))
    _broadcast_ports.add(sock.getsockname()[1])

    pongs = []
    for i, s in enumerate(servers):
        guid = 12345678901234567 + i
        pong = build_pong_packet(s["name"], s["local_port"], server_guid=guid,
                                 gamemode=s.get("gamemode", "Creative"))
        pongs.append(pong)
        print(f"[LAN] Broadcasting '{s['name']}' on port {s['local_port']}")

    while True:
        try:
            for pong in pongs:
                sock.sendto(pong, ("255.255.255.255", 19132))
                sock.sendto(pong, ("127.0.0.1", 19132))
        except OSError as e:
            print(f"[LAN] Broadcast error: {e}")
        time.sleep(interval)


def relay_from_server(upstream_sock, listen_sock, client_addr, name):
    """Relay packets from a per-client upstream socket back to that specific client."""
    while True:
        try:
            data, _ = upstream_sock.recvfrom(65535)
            listen_sock.sendto(data, client_addr)
        except OSError:
            break
        except Exception as e:
            print(f"[PROXY] {name}: relay error for {client_addr}: {e}")
            break


def proxy_udp(local_port, remote_ip, remote_port, name, all_servers=None):
    """Proxy UDP traffic between local client and remote server.

    Each client gets its own upstream socket so the remote server sees
    separate connections -- required for multiple players to connect.
    """
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind(("0.0.0.0", local_port))

    remote_addr = (remote_ip, remote_port)
    # client_addr -> {"upstream": socket, "last_seen": float}
    clients = {}
    last_cleanup = time.time()

    print(f"[PROXY] {name}: listening on :{local_port} -> {remote_ip}:{remote_port}")

    while True:
        try:
            data, addr = sock.recvfrom(65535)

            # Ignore packets from the remote server (shouldn't happen -- server
            # replies go to per-client upstream sockets) and from our own
            # broadcast socket (which sends to 127.0.0.1:19132).
            if addr[0] == remote_ip:
                continue
            if addr[1] in _broadcast_ports and addr[0] in ("127.0.0.1", "0.0.0.0"):
                continue

            # Client -> forward to server via per-client upstream socket
            if addr not in clients:
                upstream = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                clients[addr] = {"upstream": upstream, "last_seen": time.time()}
                print(f"[PROXY] {name}: new client {addr[0]}:{addr[1]}")
                t = threading.Thread(
                    target=relay_from_server,
                    args=(upstream, sock, addr, name),
                    daemon=True,
                )
                t.start()

            client = clients[addr]
            client["last_seen"] = time.time()
            client["upstream"].sendto(data, remote_addr)

            # Handle ping packets locally for LAN discovery
            if len(data) >= 25 and data[0:1] == b"\x01":
                if all_servers:
                    for i, s in enumerate(all_servers):
                        guid = 12345678901234567 + i
                        pong = build_pong_packet(s["name"], s["local_port"],
                                                 server_guid=guid)
                        sock.sendto(pong, addr)
                else:
                    pong = build_pong_packet(name, local_port)
                    sock.sendto(pong, addr)

            # Periodically clean up stale clients
            now = time.time()
            if now - last_cleanup > CLEANUP_INTERVAL:
                last_cleanup = now
                for caddr in list(clients):
                    if now - clients[caddr]["last_seen"] > CLIENT_TIMEOUT:
                        print(f"[PROXY] {name}: removing idle client {caddr[0]}:{caddr[1]}")
                        try:
                            clients[caddr]["upstream"].close()
                        except OSError:
                            pass
                        del clients[caddr]

        except Exception as e:
            print(f"[PROXY] {name}: error: {e}")


def parse_server_spec(spec):
    """Parse server spec in format ip:remote_port:local_port:name or ip:port:name."""
    parts = spec.split(":", 3)
    if len(parts) == 4:
        ip, remote_port, local_port, name = parts
        remote_port = int(remote_port)
        local_port = int(local_port)
    elif len(parts) == 3:
        ip, remote_port, name = parts
        remote_port = int(remote_port)
        local_port = remote_port
    else:
        raise ValueError(
            f"Invalid server spec: {spec} "
            f"(expected ip:port:name or ip:remote_port:local_port:name)"
        )

    if not (1 <= remote_port <= 65535):
        raise ValueError(f"Remote port out of range: {remote_port}")
    if not (1 <= local_port <= 65535):
        raise ValueError(f"Local port out of range: {local_port}")

    return {
        "remote_ip": ip,
        "remote_port": remote_port,
        "local_port": local_port,
        "name": name,
    }


def main():
    parser = argparse.ArgumentParser(
        description="Minecraft Bedrock LAN Proxy -- makes remote servers appear as LAN games",
        epilog="Each server spec is ip:remote_port:local_port:name or ip:port:name",
    )
    parser.add_argument(
        "servers", nargs="+",
        help="Server specs (ip:port:name or ip:remote_port:local_port:name)",
    )
    args = parser.parse_args()

    try:
        servers = [parse_server_spec(s) for s in args.servers]
    except ValueError as e:
        parser.error(str(e))

    # Detect duplicate local ports
    local_ports = [s["local_port"] for s in servers]
    dupes = [p for p in local_ports if local_ports.count(p) > 1]
    if dupes:
        parser.error(f"Duplicate local port(s): {sorted(set(dupes))}")

    print("=== Minecraft Bedrock LAN Proxy ===")
    for s in servers:
        print(f"  {s['name']}: {s['remote_ip']}:{s['remote_port']} -> :{s['local_port']}")
    print()

    # Start LAN broadcaster
    broadcaster = threading.Thread(target=broadcast_lan, args=(servers,), daemon=True)
    broadcaster.start()

    # Start a proxy thread for each server.
    # The server on port 19132 gets all_servers so it can respond to LAN
    # discovery pings with every server's info.
    for s in servers:
        is_discovery_port = s["local_port"] == 19132
        t = threading.Thread(
            target=proxy_udp,
            args=(s["local_port"], s["remote_ip"], s["remote_port"], s["name"],
                  servers if is_discovery_port else None),
            daemon=True,
        )
        t.start()

    # Block until Ctrl-C.  signal.pause() is cleaner than sleep-loop but
    # only works on Unix -- fine for this Linux-only tool.
    try:
        signal.pause()
    except KeyboardInterrupt:
        print("\nShutting down.")


if __name__ == "__main__":
    main()
