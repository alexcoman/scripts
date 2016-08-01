$cbslinitpath = "C:\cloudbase-init"
$branch = "bp/packet.net"
$unattendedXmlPath = "${env:programfiles}\Cloudbase Solutions\Cloudbase-Init\conf\Unattend.xml"


# Install choco
iwr https://chocolatey.org/install.ps1 -UseBasicParsing | iex
# Install git
choco install git.install --yes
# Update the PATH
$env:PATH += ";${env:programfiles}\Git\bin"
# Install Far Manager
choco install far --yes

# Remove the `Admin` user
net user Admin /DEL
# Remove the information related to cloudbase-init from registry
Remove-Item -Path "HKLM:\SOFTWARE\Cloudbase Solutions" -Recurse
# Remove logs
Remove-Item -Path "${env:programfiles}\Cloudbase Solutions\Cloudbase-Init\log" -Recurse
New-Item -Type Directory "${env:programfiles}\Cloudbase Solutions\Cloudbase-Init\log"

# Clone the required branch of cloudbase-init
git clone "https://github.com/alexcoman/cloudbase-init/" --branch "$branch" "$cbslinitpath"

# Install the update version of cloudbase-init
Pushd $cbslinitpath
& "${env:programfiles}\Cloudbase Solutions\Cloudbase-Init\Python\python.exe" setup.py install --force
Popd

# Remove the files that are not required anymore
Remove-Item -Path "$cbslinitpath" -Recurse -Force

# Run sysprep
# & "$ENV:SystemRoot\System32\Sysprep\Sysprep.exe" `/generalize `/oobe `/reboot `/unattend:"$unattendedXmlPath"
