# authentik invitations
This guide mostly follows the [official guide to setup an invite system ↗](https://docs.goauthentik.io/users-sources/user/invitations/#manual-setup-without-blueprints) in authentik. Deviations from that guide for integration with foundry are marked as such. Feel free to skip basic setup if you already have an invitation system.

## Basic Setup

> [!NOTE]
> To skip this basic setup you can download the [example template ↗](https://docs.goauthentik.io/users-sources/user/invitations/#option-1-download-the-example---invitation-based-enrollment-blueprint-recommended) from the official guide and hijack the invitation flow for internal users.
> Note that this template creates some dummy groups and invites, which can be safely deleted. If you prefer a cleaner setup, use these manual steps.

Step 1: Create an Invitation stage
- Log in to authentik as an administrator and open the authentik Admin interface.
- Navigate to Flows and Stages > Stages and click Create.
- Select Invitation Stage from the stage type list.
- Configure the stage:
  - Name: Provide a descriptive name (e.g., *foundry-invitation-stage*)
  - Continue flow without invitation:
    - Set to false
  - Click Create.

Step 2: Create or modify an Enrollment flow
- Navigate to Flows and Stages > Flows.
- Either create a new flow or edit an existing enrollment flow:
  - Name: Provide a descriptive name. (e.g., *Foundry Invitation Flow*)
  - Title: Enter the title shown to users during enrollment.
  - Slug: Enter a unique identifier (e.g., *foundry-invitation-flow*)
  - Designation: Must be set to Enrollment.
  - Authentication: Set to Require unauthenticated (users shouldn't be logged in to enroll).

Step 3: Bind the Invitation stage to the flow
- In your enrollment flow, go to the Stage Bindings tab.
- Click Bind Stage and select your invitation stage.
- Configure the binding:
  - Order: Set to a low number (e.g., 5 or 10) so it evaluates early in the flow.
  - Evaluate on plan: Enable this option so the invitation is validated when the flow starts.
  - Re-evaluate policies: Enable this to ensure policies are checked.
- Add other necessary stages to your flow (in order):
  - Prompt Stage for collecting credentials (username, password, repeat password)
  - Prompt Stage for collecting user details (name, email)
  - User Write Stage to create the user account
  - User Login Stage to log the user in after enrollment

## Modifying for Foundry
### Automatically add as player
Following the [automatic group assignment guide ↗](https://docs.goauthentik.io/users-sources/user/invitations/#automatic-group-assignment):
- Flows and Stages > Flows > Edit your Foundry Invitation Flow
- In Stage Bindings, edit the user write stage
- Set group to your player group

### Secure Foundry usernames
Since Foundry depends on an exact match, user must be disallowed to change this field. This means that it depends on the field that stores your Foundry usernames.
#### Matching default authentik username ("The easy way")

- Flows and Stages > Flows > Edit your Foundry Invitation Flow
- In Stage Bindings, edit the Prompt stage that contains setting the username
- Either
  - Remove the username field
  - Edit the username field to something uneditable
- System > Settings > Ensure "Allow user to change username" is not set

#### Matching custom attribute ("The hard way")

Nothing to secure.

If you want to show the Foundry username during registration, add a static prompt to any [prompt stage ↗](https://docs.goauthentik.io/add-secure-apps/flows-stages/stages/prompt/).

## Inviting a user

1. [Create an invitation object ↗](https://docs.goauthentik.io/users-sources/user/invitations/#step-3-create-the-invitation-object)
2. Fill attributes depending on where your Foundry username is stored
    - authentik username ("The easy way")
      > Set root variable "username". Example:
      > ```yaml
      > username: YourFoundryUsername
      > ```
    - custom attribute ("The hard way")
      > Fill in your custom attribute as normal. Example:
      > ```yaml
      > foundry:
      >   user: YourFoundryUsername
      > ```
3. Share your invitation link
