# Mesh Join Specification

## Purpose

How a machine declared in this flake becomes a reachable member of the luninet WireGuard mesh.

## Requirements

### Requirement: A declared machine joins on switch

A machine whose configuration includes the luninet module SHALL bring up one WireGuard
interface named `asluni` with the mesh address the owner provisioned, an MTU of 1420, and the
peer set from the pinned luninet input.

#### Scenario: The interface comes up

- **WHEN** `nixos-rebuild switch` completes on the machine
- **THEN** `wg show asluni` lists the hub peer
- **AND** the interface carries the provisioned address

#### Scenario: A handshake proves reachability

- **WHEN** the machine has been up for one keepalive interval
- **THEN** `wg show asluni` reports a recent handshake with the hub
- **AND** a host inside `172.29.64.0/18` answers a ping

### Requirement: A NATed host keeps its mapping open

A machine without a public listen port SHALL send a persistent keepalive to the hub, because
the hub can only reach it through a mapping this side keeps alive.

#### Scenario: No inbound port

- **GIVEN** the machine sets no `listenPort` and forwards no port
- **WHEN** the interface is up
- **THEN** the hub peer carries `persistentKeepalive`
- **AND** outbound traffic to the hub succeeds

### Requirement: Mesh DNS is scoped

The machine SHALL resolve names under `luni` through the mesh resolver, and only those names.

#### Scenario: A mesh name resolves

- **WHEN** the machine resolves a name under `luni`
- **THEN** the query goes to the mesh resolver
- **AND** other domains keep the host's own resolver
