# Sonarr Cleanup

Cleans up stuck downloads.
Specifically downloads that do not contain a media file or contain potential viruses.

Identifies downloads in Sonarr's queue that are completed but stuck in an `importPending` warning state — typically caused by no eligible files or dangerous content flags. Removes and blocklists each offending item, then triggers a new search.

---

## Requirements

- PowerShell 5.1+
- An API key with read/write queue access in Sonarr

---

## Usage

```powershell
.\sonarr-cleanup.ps1 -Url "http://<sonarr-host>:<port>" -ApiKeyPath "<path-to-key-file>"
```

### Example

```powershell
.\sonarr-cleanup.ps1 -Url "http://192.168.1.10:8989" -ApiKeyPath "C:\secrets\sonarr.key"
```

The API key file should be a plain text file containing only your Sonarr API key.

---

## Parameters

| Parameter    | Type   | Required | Default | Description                                                                 |
|--------------|--------|----------|---------|-----------------------------------------------------------------------------|
| `-Url`       | String | Yes      | —       | The base URL of your Sonarr instance, including protocol and port. e.g. `http://localhost:8989` |
| `-ApiKeyPath`| String | Yes      | —       | Path to a plain text file containing your Sonarr API key.                  |

---

## How It Works

1. Fetches all items currently in Sonarr's download queue.
2. Filters for items that are `completed` but stuck in a `warning / importPending` state.
3. Further filters for items flagged with either:
   - `No files found are eligible for import` — nothing usable in the download.
   - `Dangerous` — the download was flagged as a potential threat.
4. Removes each matched item from the queue, blocklists it, and lets Sonarr trigger a new search.

---

## NixOS — Flake Overlay

A NixOS module is included via the flake. It wraps the PowerShell script in a systemd service and timer so cleanup runs automatically on a schedule.

### Importing the Flake

In your `flake.nix`:

```nix
inputs.sonarr-cleanup.url = "github:<your-username>/sonarr-cleanup";
```

Then include the module in your NixOS configuration:

```nix
nixosModules = [ inputs.sonarr-cleanup.nixosModules.default ];
```

### Configuration

```nix
services.sonarr-cleanup = {
  enable = true;
  url = "http://127.0.0.1:8989";   # optional, this is the default
  keyPath = config.age.secrets.sonarr_key.path;
  interval = "hourly";             # optional, this is the default
};
```

### Module Options

| Option      | Type   | Default                  | Description                                                                 |
|-------------|--------|--------------------------|-----------------------------------------------------------------------------|
| `enable`    | Bool   | —                        | Enables the Sonarr Cleanup service and timer.                              |
| `url`       | String | `http://127.0.0.1:8989`  | URL to the Sonarr instance. Must include protocol (`http`/`https`) and port.|
| `keyPath`   | String | `/root/sonarr-key`       | Path to the file containing the Sonarr API key.                            |
| `interval`  | String | `hourly`                 | How often to run cleanup. Accepts any [systemd calendar expression](https://www.freedesktop.org/software/systemd/man/systemd.time.html). |

### Notes

- The service runs as a dedicated `sonarr-cleanup` system user and group.
- `powershell` is added to the service's PATH automatically.
- The systemd timer targets `timers.target` and fires based on the configured `interval`.