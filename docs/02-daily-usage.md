# Daily Usage - K3D Jenkins Environment

## Basic Workflow

```bash
# Load credentials (once per shell session)
source .env.credentials

# Run setup (Jenkins only)
make setup
# OR
./k3d-setup.sh

# Later... teardown
make teardown
# OR  
./k3d-teardown.sh
```

## Available Make Commands

```bash
make setup              # Full setup (Jenkins only)
make kubeconfig         # Generate/update k3d-kubeconfig file
make teardown           # Complete teardown
make teardown-keep-vol  # Teardown but keep data volume
make teardown-keep-all  # Teardown but keep volume and images
make status             # Check current status
make clean              # Remove generated files
make check-env          # Check if credentials are loaded
make help               # Show help
```

## Quick Reference

- **First time setup**: `source .env.credentials` then `make setup`
- **Daily start**: `make setup` (if cluster was torn down)
- **Daily stop**: `make teardown-keep-vol` (preserves data)
- **Check status**: `make status`
- **Update kubeconfig**: `make kubeconfig` (after cluster changes)