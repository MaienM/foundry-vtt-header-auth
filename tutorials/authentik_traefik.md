# Authentik + Traefik Proxy Setup

This guide supposes you have a working Authentik and Traefik setup on docker. Specifically here Traefik is label focused, with files for the dynamic configuration, but the same can be achieved with all the other configuration methods.

> Important: user profiles need to be created in FoundryVTT before they can login. The user names in FoundryVTT must match the user names in Authentik, otherwise the login will fail. This is because FoundryVTT uses the `x-authentik-username` header to identify users.

## Modifying the patch

You can skip the next 2 sections if you follow this [Tutorial](https://docs.ibracorp.io/authentik/authentik/docker-compose/traefik-forward-auth-single-applications) to set up Authentik with Traefik Forward Auth.

## Traefik Forward Auth Configuration

> Note: if you already have http and middlewares section in your dynamic config you only need to add the authentik portion
> Note: this middleware can be used with any application, not just with FoundryVTT

```yaml
http:
  middlewares:
    authentik:
      forwardauth:
        address: http://authentik-server:9000/outpost.goauthentik.io/auth/traefik
        trustForwardHeader: true
        authResponseHeaders:
          - X-authentik-username
          - X-authentik-groups
          - X-authentik-email
          - X-authentik-name
          - X-authentik-uid
          - X-authentik-jwt
          - X-authentik-meta-jwks
          - X-authentik-meta-outpost
          - X-authentik-meta-provider
          - X-authentik-meta-app
          - X-authentik-meta-version
```

where <authentik-server> is the name of your Authentik container.

## Authentik

[Authentik](https://goauthentik.io/)

Create a new applicatio with a Proxy Provider. Name it as you prefer, mine was `FoundryVTT`, set the **Extenal Host** as `foundry.<your-domain>`, you can also set the Authorization flows to be **Implicit** or **Explicit**, mine is Implicit for simplicity.

Next go to the **Outpost** section, edit the default outpost and select the application you just created.
Additionally edit the `authentik_host:` line and replace the URL with the subdomain.yourdomain.tld you use to access authentik externally

Create 2 roles with relative groups, or as you prefer (we need the group names later):

- `foundry-admin`
- `foundry-user`

Add users you want as players to the `foundry-user` group, and users you want as admins to the `foundry-admin` group. Remember that admin users can play as players too; they don't have to be put in both groups.

## FoundryVTT

```YAML
foundry:
    image: felddy/foundryvtt:13.346.0
    container_name: foundry
    restart: unless-stopped
    volumes:
      - <DATA_VOLUME>:/data
    environment:
      - FOUNDRY_PASSWORD=<FOUNDRY_PASSWORD>
      - FOUNDRY_USERNAME=<FOUNDRY_USERNAME>
      - CONTAINER_PATCHES=/data/patch_dir

      - HEADER_USERNAME=x-authentik-username    # This needs to be lowercase and present as X-authentik-username in traefik dynamic config
      - HEADER_ROLES=x-authentik-groups         # As above, but X-authentik-groups
      - HEADER_ROLES_SEPARATOR='|'              # The default is ',', but Authentik uses '|'.
      - ROLE_PLAYER=foundry-player              # This is the group name you set in Authentik for players
      - ROLE_ADMIN=foundry-admin                # This is the group name you set in Authentik for admins

      - FOUNDRY_ADMIN_KEY=<FOUNDRY_ADMIN_PASSWORD> # The admimn password is needed so that the admin login is performed only by `foundry-admin` users, otherwise anyone can login on the setup page
    networks:
      - proxy-net
    labels:
      - traefik.enable=true
      - traefik.docker.network=proxy-net
      - traefik.http.routers.foundry-secure.entrypoints=websecure
      - traefik.http.routers.foundry-secure.rule=Host(`foundry.$DOMAIN`)
      - traefik.http.routers.foundry-secure.tls=true
      - traefik.http.routers.foundry-secure.tls.certresolver=$CERTRESOLVER

      - traefik.http.routers.foundry-secure.service=foundry-service
      - traefik.http.routers.foundry-secure.middlewares=authentik@file # This is the middleware we created in the dynamic config

      - traefik.http.services.foundry-service.loadbalancer.server.port=30000 # Loadbalancing on the port. If you change it on the env_variables of the container, change it here too
      - traefik.http.services.foundry-service.loadbalancer.server.scheme=http
```

This way you can access FoundryVTT as specified in the README, it will be access protected by Authentik and users will be automatically logged in based on their Authentik roles.

Have fun!
