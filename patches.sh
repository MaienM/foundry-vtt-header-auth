#!/usr/bin/env bash

HEADER_USERNAME="${HEADER_USERNAME:-"x-auth-request-preferred-username"}"
HEADER_ROLES="${HEADER_ROLES:-"x-auth-request-groups"}"
ROLE_PLAYER="${ROLE_PLAYER:-"role:foundry-vtt:player"}"
ROLE_ADMIN="${ROLE_ADMIN:-"role:foundry-vtt:admin"}"

# usage: $0 patch-name file [sed-expression]
# Utility to use sed to patch a file, verifying that it actually changed something.
# The sed expression can either be passed as an argument or piped in (e.g. using a heredoc).
patch_sed() (
	name="$1"
	file="$2"
	expression="${3:-$(cat)}"

	if ! [ -f "$file" ]; then
		>&2 echo "File '$file' does not exist."
		exit 1
	fi
	before="$(md5sum "$file")"
	sed -i "$expression" "$file"
	after="$(md5sum "$file")"
	if [ "$before" = "$after" ]; then
		>&2 echo "Failed to apply patch $name to $file (no change)."
		exit 1
	else
		echo "Applied patch $name to $file."
	fi
)

# usage: $0 name file [text]
# Utility to append to a file, with a check whether the file exists first (else it wouldn't really be a patch).
# The text can either be passed as an argument or piped in (e.g. using a heredoc).
patch_append() (
	name="$1"
	file="$2"
	text="${3:-$(cat)}"

	if ! [ -f "$file" ]; then
		>&2 echo "File '$file' does not exist."
		exit 1
	fi
	printf '%s\n' "$text" >> "$file"
	echo "Applied patch $name to $file."
)

# Replace admin password check with header check.
patch_sed admin-header-login resources/app/dist/sessions.mjs "s/testPassword(\(\w\+\)\.body\.adminPassword,\w\+,getSalt(config.passwordSalt))/(s.headers['$HEADER_ROLES'].split(',').includes('$ROLE_ADMIN'))/"

# Replace user password check with header check. In addition to the player themselves admins will also be allowed to log in as any player.
patch_sed user-header-login resources/app/dist/sessions.mjs "s/testPassword(\w\+,\(\w\+\)\.password,\w\+.passwordSalt)/((s.headers['$HEADER_USERNAME'].toLowerCase() === \1.name.toLowerCase() \&\& s.headers['$HEADER_ROLES'].split(',').includes('$ROLE_PLAYER')) || s.headers['$HEADER_ROLES'].split(',').includes('$ROLE_ADMIN'))/"

# Hide password fields.
patch_append hide-password-fields resources/app/public/css/foundry2.css << END
	#join-game .form-group:has(input[type="password"]),
	#setup-authentication .form-group:has(input[type="password"]) {
		display: none;
	}
END

# Pass information about the user info from the headers to the client side. This is used for auto-login behavior, as well as to hide elements that aren't relevant for players.
patch_sed track-header-info resources/app/dist/sessions.mjs "s/global\.logger\.info(\`Created client session \${\(\w\+\)\.id}\`)/(t.headerInfo = { username: s.headers['$HEADER_USERNAME'], isAdmin: s.headers['$HEADER_ROLES']?.split(',')?.includes('$ROLE_ADMIN') ?? false }), &/"
patch_sed track-header-info resources/app/dist/server/sockets.mjs 's/\(\w\+\)\.sessionId=\(\w\+\)\.id/&,\1.headerInfo = \2.headerInfo/'
patch_sed track-header-info resources/app/public/scripts/foundry.mjs 's/id = response\.sessionId;/& localStorage.headerInfo = JSON.stringify(response.headerInfo);/'
patch_append track-header-info resources/app/public/scripts/foundry.mjs << END
	window.withHeaderInfo = (cb) => {
		if (localStorage.headerInfo) {
			const headerInfo = JSON.parse(localStorage.headerInfo);
			cb(headerInfo);
		} else {
			setTimeout(() => withHeaderInfo(cb), 50);
		}
	};
END
patch_append add-non-admin-class resources/app/public/scripts/foundry.mjs << END
	window.withHeaderInfo((headerInfo) => {
		if (!headerInfo.isAdmin) {
			document.body.classList.add('header-info-non-admin');
		}
	});
END

# Auto-login users.
# shellcheck disable=2016
patch_append auto-login resources/app/public/scripts/foundry.mjs << END
	window.withHeaderInfo((headerInfo) => {
		// Check to see if the main form/placeholder exists, if it does not we're not on the right page and can just abort.
		if (!document.querySelector('#join-game')) {
			return;
		}

		// Add class to body to hide the form while the auto-login is in progress. This should be undone if the process
		// fails to allow the user to select their user manually..
		if (!headerInfo.isAdmin) {
			document.body.classList.add('login-in-progress');
		}
		const showForm = () => {
			document.body.classList.remove('login-in-progress');
		}

		const waitForTemplate = () => {
			// Grab the join form & elements. If they're not present yet schedule a retry as the template has not been rendered yet.
			const form = document.querySelector('#join-game-form');
			if (!form) {
				setTimeout(waitForTemplate, 50);
				return;
			}
			const select = form.querySelector('select[name="userid"]');
			const joinButton = form.querySelector('button[name="join"]');

			// Try to find & select the matching user, aborting if none is found.
			const item = Array.from(select?.options ?? []).find((i) => i.textContent.toLowerCase() === headerInfo.username);
			if (!item) {
				console.warn('Cannot find user to auto-login as.');
				showForm();
				return;
			}
			item.selected = true;
			select.dispatchEvent(new Event('focus'));

			// An admin can login as any user & go to the setup from this screen, so we'll stop after selecting their user.
			if (headerInfo.isAdmin) {
				return;
			}

			// Attempt to auto-login regular users, waiting for the notification to appear to ensure it succeeded.
			let attempts = 0;
			const notifications = document.querySelector('#notifications');
			const tryLogin = () => {
				if (notifications && notifications.textContent.includes('joining game')) {
					console.log('Auto-login succeeded.');
					return;
				}

				joinButton.click();

				attempts += 1;
				if (attempts < 10) {
					setTimeout(tryLogin, Math.max(200, 50 * attempts));
				} else {
					console.warn('Auto-login failed.');
					showForm();
				}
			};
			console.log('Attempting auto-login.');
			tryLogin();
		}
		waitForTemplate();
	});
END
patch_append hide-login-form-during-autologin resources/app/public/css/foundry2.css << END
	body.header-info-non-admin.login-in-progress #join-game-form {
		display: none;
	}
END
patch_append hide-non-admin-logout resources/app/public/css/foundry2.css << END
	body.header-info-non-admin #settings button[data-app="logout"],
	body.header-info-non-admin #settings section.access {
		display: none;
	}
END

# Hide/change setup related items for non-admin users.
patch_append hide-non-admin-setup resources/app/public/css/foundry2.css << END
	body.header-info-non-admin #join-game-setup,
	body.header-info-non-admin #setup-authentication form *:not(h2) {
		display: none;
	}
	body.header-info-non-admin #setup-authentication form > h2::after {
		content: "This server is currently in setup mode and cannot be used by players.";
		font-size: 50%;
		display: block;
		margin-top: 0.5em;
	}
END
