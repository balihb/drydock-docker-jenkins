# Drydock host for Jenkins trigger (in Docker)

This is an example of how to build a Docker image for triggering Jenkins builds from Drydock. The Docker part probably won't work out of the box, but the trigger_build.sh script can be used in environments other than Docker.

## Setup

This setup will consist of a few interdependent steps. You can run multiple Drydock hosts, but they need a fixed host:port pair. The dockerized Drydock hosts will need a persisted user home since Phabricator expects the previously created working copies to exist and recreating the container would destroy them. This could be done by a volume (or other persistence solution). This solution expects Staging Area for the repository.

 1. Ph -> Almanac -> Networks. Add a network.
 2. Ph -> Almanac -> Devices. Add as many host:ports as you will have. Use the previously created network.
 3. Ph -> Almanac -> Services. Add a new service and bind the devices to it.
 4. Create a new ssh key (any method you choose). Fol later reference, let’s call this the drydock-host key.
 5. Ph -> Drydock -> Blueprints. Create a new Almanac Hosts blueprint. Set the previous Almanac Service as the Almanac Service. Add the private key part of the drydock-host key as a new credential. The username must be the same in the Dockerfile as in the credential.
 6. Ph -> Drydock -> Blueprints. Create a new Working Copy blueprint. Set the previous blueprint in the Use Blueprint part.
 7. Ph. Create a new bot user and download the public key for the user. For later reference let’s call this the drydock-user key.
 8. Create and start the container(s). If you choose the volume solution for working copy persistence and haven't changed the ssh configuration, you must create a directory for the container to use for the service user (phabricator-drydock in the example Dockerfile). The owner of this directory must have the same uid as the service user. Inside the directory create a .ssh directory with 700 mask. Add the drydock-user public key to the authorized_keys and add the drydock-host key as id_rsa. Both with 600 mask. Adjust the config file as needed.
 9. Start the container: `docker run -d -p <external port>:22 --name drydock --restart always -v <workspace dir on host>:/var/drydock`
 10. Jenkins. Add a new user and log in with it. Get its token and give it the needed rights (or control it on a per job bases). Overall: Read; Job: Build, Read, Workspace.
 11. Ph -> Harbormaster -> Manage Build Plans. Create a new Build Plan. You will need two steps.
     1. Lease. In Use Blueprint set the 2nd blueprint (the working copy one).
     2. Call Jenkins. The Drydock Lease must be the same as the Artifact Name from the previous step. The command is: `trigger_build.sh --base-url=<jenkins base url> --job-path=job/${repository.callsign}/job/review/buildWithParameters --user=<jenkins user name> --token=<jenkins user token> --params=STREF=${repository.staging.ref}\&DIFF_ID=${buildable.diff}\&PHID=${target.phid} --verbose --wait`. The job path can be different. In this case, I'm using the build for review. The idea here is to use the repository callsign as a folder name in Jenkins (the display name of the folder can be different).
 12. Ph -> Herald. Create a new Rule. Choose Differential Revisions. I'm using Global rule with the repositories set with "Repository is any of" condition. Pick Run Build Plan as the action and choose the previously created build plan.
 13. Jenkins. Create the Job with the STREF, DIFF_ID and PHID parameters. "Branches to build" should be set to ${STREF}.

## Some notes
In case the permanent storage for the workspace is destroyed, the related resources must be deleted from Phabricator.

