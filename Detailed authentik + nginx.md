# nginx (reverse proxy) → authentik (proxy auth) → FoundryVTT

Please read a few disclaimers:
1. This is a very basic setup guide. It assumes core knowledge of anything not outlined in the title.
2. This writeup references outside sources where possible. This is to keep it as up-to-date as possible. As long as outside sources are still accessible, **please use them**.
3. The author of this guide is **not a security expert** and thus not to be held responsible. 

## Prerequisites

> [!IMPORTANT]
> Basic nginx configuration to serve your services is outside the scope of this guide.

### What this guide assumes you have

- A running and configured instance of...
	- [FoundryVTT ↗](https://github.com/felddy/foundryvtt-docker) (preferably `felddy/foundryvtt` as compose file)
	- [authentik ↗](https://docs.goauthentik.io/install-config/)
	- [nginx ↗](https://nginx.org/en/docs/) as reverse proxy
- authentik nginx [reverse proxy config ↗](https://docs.goauthentik.io/install-config/reverse-proxy/)
- FoundryVTT nginx [reverse proxy config ↗](https://foundryvtt.com/article/nginx/)

### What this guide covers

- Configuring authentik application/provider/outpost (optionally remote outpost)
- Configuring authentik/outpost as proxy
- Configuring authentik to serve custom headers
- Modifying your `felddy/foundryvtt` compose file
- Modifying your nginx server directive for FoundryVTT

## Preparing authentik

> [!NOTE]
> This Foundry patch requires 2 headers:
> - A role distinction between admins, players and unauthorized users
> - A username to match any FoundryVTT user (needed for player-role)


### Foundry role distinction
In authentik [create groups ↗](https://docs.goauthentik.io/users-sources/groups/manage_groups/#create-a-group) for:
- foundry-admins (can access setup page and any user account)
- foundry-players (can access only their user account; can't log in if username is missing)

Assign new or existing users these groups to grant them FoundryVTT privileges.

### Foundry username matching

> [!IMPORTANT]
> This guide covers two options on this, the easy and hard way.
> The easy way | The hard way
> :----------: | :----------:
> Quickest setup | More steps and difficult to understand
> Foundry username is always authentik username | Usernames can differ
> Restricts editing usernames | Usernames are independently editable
> 
> Pick your poison. Whenever your choice is mentioned you should follow it.

#### The easy way
If you make it a requirement that the authentik username must match the foundry username, you can skip this step. Please note that doing so may have side effects because users can change their username by default.

#### The hard way (recommended)
This way, you'll set a custom attribute, that can only be set by an authentik admin. Setup is a bit more difficult because authentik does not set custom attributes in headers automatically. You can follow the [official custom headers guide ↗](https://docs.goauthentik.io/add-secure-apps/providers/proxy/custom_headers/) or this one.

1. Under Customization > Property Mappings > Create a new mapping
2. Select type "Scope Mapping" and continue
3. Input the first three fields however you like
4. For "Expression" enter:
	```py
	return {
	    "ak_proxy": {
	        "user_attributes": {
	            "additionalHeaders": {
	                "X-Foundry-Username": request.user.attributes.get("foundry", {}).get("user", None)
	            }
	        }
	    }
	}
	```
5. For any new or existing user enter the attribute as follows:
	```yaml
	foundry:
	  user: FoundryUserName
	```
	Where `FoundryUserName` is the matching username inside FoundryVTT.

## Configuring authentik SSO

[Create a Proxy Provider ↗](https://docs.goauthentik.io/add-secure-apps/providers/proxy/) with the following values:
- **Type: Proxy**
    If you are planning to use forward auth, this guide might not be for you.

-  **Internal host**
   Set this to the internally accessible HTTP-Address of your FoundryVTT container.
    
   If your FoundryVTT container is on the same docker host as authentik, [setup a shared network ↗](https://docs.docker.com/compose/how-tos/networking/#use-an-existing-external-network) and set the value to  `http://foundryvtt:30000`, where `foundryvtt` is the name of your FoundryVTT container.
    
   If FoundryVTT is running on a different server than authentik, [setup an authentik remote proxy outpost ↗](https://docs.goauthentik.io/add-secure-apps/outposts/manual-deploy-docker-compose/) on the same host as your FoundryVTT container. After that follow the instructions above.
    
-  **External host**
   Set this to the external URL you are accessing FoundryVTT from. For example: `https://vtt.example.com`
    
- Under **Advanced protocol settings**
    Add the custom scope mapping you created above.
    
[Create an application ↗](https://docs.goauthentik.io/add-secure-apps/applications/) in authentik and select the provider you've created above.
- **Configure Bindings**
  Additionally in authentik, go to your Foundry application and add a group policy for each of the two new groups. This is optional but recommended. This way not every authentik user can see your foundry instance.

[Configure your outpost ↗](https://docs.goauthentik.io/add-secure-apps/outposts/#create-and-configure-an-outpost) in authentik and add the application you've created above.

## Modifying your nginx config

Ensure [required authentik headers ↗](https://docs.goauthentik.io/install-config/reverse-proxy/) are set.

-   `X-Forwarded-Proto`: Tells authentik and Proxy Providers if they are being served over an HTTPS connection.
-   `X-Forwarded-For`: Without this, authentik will not know the IP addresses of clients.
-   `Host`: Required for various security checks, WebSocket handshake, and Outpost and Proxy Provider communication.
-   `Connection: Upgrade`  and  `Upgrade: WebSocket`: Required to upgrade protocols for requests to the WebSocket endpoints under HTTP/1.1.

Change your `proxy_pass` directive.
```diff
-   proxy_pass http://127.0.0.1:30000 # Port to FoundryVTT
+   proxy_pass http://127.0.0.1:9000  # Port to authentik proxy outpost
```

## Patching your FoundryVTT deployment
Add the following Environment-Variables to your compose file:
```yaml
[...]
environment:
  - [...]
  - CONTAINER_PATCHES=/data/patch_dir
  - HEADER_USERNAME=x-foundry-username
  - HEADER_ROLES=x-authentik-groups
  - HEADER_ROLES_SEPARATOR=|
  - ROLE_PLAYER=foundry-players
  - ROLE_ADMIN=foundry-admins
  - FOUNDRY_ADMIN_KEY=YOURADMINKEY
  - [...]
```
- `CONTAINER_PATCHES`
	Set to any available binding and upload a matching release of the patch to this directory
- `HEADER_USERNAME`
  Set to `x-authentik-username` if you used the easy way above
- `HEADER_ROLES`
  For role distinction
- `HEADER_ROLES_SEPARATOR`
  For role distinction; Authentik uses pipe for seperation
- `ROLE_PLAYER`
  Group name of your players
- `ROLE_ADMIN`
  Group name of your admins
- `FOUNDRY_ADMIN_KEY`
  The password to enter the foundry Setup-Page

Redeploy using `docker compose up -d`

## How to authorize users

> [!IMPORTANT]
> In Foundry, each user has to have their own account using a distinct username. Please follow the [Foundry documentation ↗](https://foundryvtt.com/article/users/) to create one.

> [!IMPORTANT]
> In authentik, each user has to have their own account. See [authentik's official documentation ↗](https://docs.goauthentik.io/users-sources/user/user_basic_operations/#create-a-user) on this.

1. Add the new or existing authentik user to either the foundry-admins or foundry-players group from above.
2. Depending on your chosen way to handle Foundry username matching, certain modifications have to be made:
   - The easy way
     > Ensure that the authentik Username field value is the exact same as the Foundry Username.

   - The hard way
     > Add the required attributes for the authentik user
     > ```yaml
     > foundry:
     >   user: FoundryUserName
     > ```

## Profit?

Any user visiting your Foundry instance will now be prompted to login using authentik.
Additionally any authenticated user visiting your authentik instance will see your Foundry instance in their applications.

