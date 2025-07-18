# Suggestion: Add periodic DNS re-resolution for Endpoint in WireGuard iOS client

## Background

Currently, the WireGuard iOS client resolves the DNS name of the Endpoint only once, when the tunnel is activated. If the server’s IP address changes (e.g., dynamic IP with DDNS services like No-IP), the client keeps trying to connect to the old IP, causing the tunnel to fail silently.

## Problem

iOS WireGuard does not re-resolve the DNS name of the Endpoint periodically, nor does it refresh the connection if the IP behind the hostname changes.

## Proposed solution

Implement a periodic DNS re-resolution mechanism in the iOS client:

- Detect if the Endpoint is a hostname (not a raw IP)
- Set a timer (e.g., every 60 seconds) to re-resolve the DNS for the Endpoint hostname
- If the resolved IP has changed, update the WireGuard peer’s Endpoint accordingly (using the appropriate API)
- Re-establish the connection seamlessly without requiring manual toggle

## Benefits

- Improves user experience for people with dynamic IP servers
- Avoids manual tunnel toggling on IP changes
- Aligns with behaviors of other VPN clients (OpenVPN, Tailscale)

## Implementation notes

- Use `Timer.scheduledTimer` in Swift for periodic checks
- Use system DNS resolver APIs to resolve the hostname
- Integrate with `WireGuardNetworkExtension` to update the peer endpoint dynamically
- Ensure minimal impact on battery and system resources

## Conclusion

This feature would greatly improve usability on mobile devices and dynamic network environments.

Thank you for considering this enhancement!

Best regards,  
Rafael
