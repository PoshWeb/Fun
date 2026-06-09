# Kali linux already has a powershell package, which makes this a simple base.
FROM kalilinux/kali-rolling

# We accept the list of packages to install as a build argument (we only absolutely need powershell, but others are useful)
ARG INSTALL_PACKAGES="powershell git wget curl ca-certificates libc6 libgcc1"

# Update the list of packages
RUN apt-get update && apt-get install -y ${INSTALL_PACKAGES}


# Run the initialization script
RUN --mount=type=bind,src=./,target=/Initialize /bin/pwsh -nologo -file ./Initialize/Container.init.ps1

# Start the container with this script
ENTRYPOINT [ "/bin/pwsh", "-nologo", "-noexit", "-file", "/Container.start.ps1" ]