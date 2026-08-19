---
paths: ["**/*network*/**", "**/*multiplayer*/**", "**/*rpc*/**", "**/*peer*/**", "**/*net*.gd"]
---

# Multiplayer Rules

This project uses Godot multiplayer networking.

## Authority

Before modifying networked code, determine:
- Which peer has authority.
- Whether the code executes on the server or a client.
- Which peer owns the relevant state.
- Whether the state is authoritative or replicated.

Never assume authority without checking the existing implementation.

## RPC

When modifying an RPC:
- Check who can call it.
- Check who executes it.
- Check its RPC configuration.
- Check whether it can execute more than once.
- Check whether the caller and receiver are on the expected peers.

## Server and client

When debugging multiplayer behavior, explicitly trace:

```text
Server
Client A
Client B
...
```