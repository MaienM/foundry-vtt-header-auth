# Foundry VTT - Header-based authentication

This project is a script that when ran patches the code of Foundry VTT such that it will use the headers that are
provided by an authentication proxy to authenticate the users. **This will completely replace password-based
authentication**, so make sure that all users will have the right headers set!

## Functionality

Based on the headers provided by the authentication proxy (see configuration) the user's username & roles are
determined, and then the authentication proceeds as follows:

- If the admin role is present the user is treated as an admin. They will be able to go to the setup, and they can login
  as any player. The player matching their username is preselected (if present) but not automatically logged in with.
- If the player role is present the user is treated as a player. The player matching their username (if present) will be
  selected and automatically logged in. If no such player exists they will be unable to login.
- If neither role is present the user will be presented with the login screen, but they will not be able to login since
  password-based authentication is disabled.

### Examples

<!-- It's dumb that GitHub requires you to manage these videos outside the repo. -->

Logging in with admin access & joining the game:

https://github.com/user-attachments/assets/a485bff5-3323-4758-8c47-776b2fd98880

Logging in with admin access & going to the setup:

https://github.com/user-attachments/assets/6f4258d7-30fb-4022-9bf3-2b148cebcce1

Logging in with player access & automatically joining the game:

https://github.com/user-attachments/assets/2550b9e5-070f-4ccb-820c-e56bff18eb80

Logging in with player access without a matching player in the game:

https://github.com/user-attachments/assets/5f0b3f3a-01ef-45a7-98da-5e609ef02f58

## Installation

This is intended to be used via the `CONTAINER_PATCHES` or `CONTAINER_PATCH_URLS` environment of [felddy's
foundryvtt-docker](https://github.com/felddy/foundryvtt-docker) image, but it can probably also be used from outside of
that with a bit of extra work.

You must already have an authentication proxy setup that providers headers to the application containing the username &
roles (see the configuration section). This is not included in the example.

Example setup:

```yaml
---
services:
  foundry:
    image: felddy/foundryvtt:13
    hostname: my_foundry_host
    volumes:
      - type: bind
        source: <your_data_dir>
        target: /data
    environment:
      - FOUNDRY_PASSWORD=<your_password>
      - FOUNDRY_USERNAME=<your_username>
      - CONTAINER_PATCH_URLS=<get_url_from_releases>
    ports:
      - target: 30000
        published: 30000
        protocol: tcp
```

## Configuration

This script uses the following environment variables to determine what headers & roles to use. The default headers match
those used by [OAuth2 Proxy](https://oauth2-proxy.github.io/oauth2-proxy/) with [the `--set-xauthrequest`
option](https://oauth2-proxy.github.io/oauth2-proxy/configuration/overview?_highlight=xauth#header-options) enabled.

| Name | Purpose | Default |
| --- | --- | --- |
| `HEADER_USERNAME` | The header to look at for the username. Usernames are matched (ignoring case) with the names of the players in the game. | `x-auth-request-preferred-username` |
| `HEADER_ROLES` | The header to look at for the roles. This must be a comma-separated list. | `x-auth-request-groups` |
| `ROLE_PLAYER` | The role that marks someone as a player. | `role:foundry-vtt:player` |
| `ROLE_ADMIN` | The role that marks someone as an admin. | `role:foundry-vtt:admin` |
