# Gabbro

Steps for success

1. change detection to get list of services to
    - add
    - redeploy
    - prune
2. combine all services into master docker compose file
3. combine master dc file with overrides file for volumes
4. combine all service env files and check for conflicts
5. save combined env file and dc file as artifacts before next step
---
6. hydrate secrets into env file - secret key is in env of runners
7. hydrate env file into `sub.gabbro` files
8. deploy / prune services listed by change detection