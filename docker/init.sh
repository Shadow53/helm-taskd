#!/bin/sh

## HELPER FUNCTIONS ##

equal_files() {
    local left="$1"
    local right="$2"

    [ "$(cat "$left")" = "$(cat "$right")" ]
}

## ENSURE VARIABLES ARE VALID ##

if [ -z "$TASKDDATA" ] || [ ! -d "$TASKDDATA" ]; then
    echo "Invalid TASKDDATA: $TASKDDATA" 1>&2
    exit 1
fi

if [ -z "$TASKD_HOST" ]; then
    echo "TASKD_HOST is required" 1>&2
    exit 1
fi

TASKD_PORT="${TASKD_PORT:-53589}"

TASKDPKI="${TASKDDATA}/pki"

mkdir -p "$TASKDPKI"

## INIT TASKD ##
echo "Initializaing taskd server"
taskd init &> /dev/null
cp -rf /usr/share/taskd/pki/* "${TASKDPKI}/"

## CREATE CERTIFICATES ##
cd $TASKDPKI

cat << EOF > ./vars.new
BITS=${CA_BITS}
EXPIRATION_DAYS=${CA_EXPIRATION_DAYS}
ORGANIZATION="${CA_ORGANIZATION}"
CN=${TASKD_HOST}
COUNTRY=${CA_COUNTRY}
STATE="${CA_STATE}"
LOCALITY="${CA_LOCALITY}"
EOF

reset_server=false

if [ ! -f "./vars" ] || ! equal_files "./vars" "./vars.new"; then
    reset_server=true
    mv "./vars.new" "./vars"
    echo "Generating new server keys"
    ./generate &> /dev/null

    taskd config --force client.cert $TASKDPKI/client.cert.pem
    taskd config --force client.key  $TASKDPKI/client.key.pem
    taskd config --force server.cert $TASKDPKI/server.cert.pem
    taskd config --force server.key  $TASKDPKI/server.key.pem
    taskd config --force server.crl  $TASKDPKI/server.crl.pem
    taskd config --force ca.cert     $TASKDPKI/ca.cert.pem
fi

cd "$TASKDDATA"

taskd config --force log      /var/log/taskd.log
taskd config --force pid.file /var/run/taskd.pid
taskd config --force server   0.0.0.0:$TASKD_PORT

## CREATE ORGS AND USERS ##

# TASKD_USERLIST="group/user:group/user:group/user"

OIFS=$IFS
IFS=:
for item in $TASKD_USERLIST; do
    # Split variable into org and user
    orgname="$(echo "$item" | cut -d'/' -f 1)"
    username="$(echo "$item" | cut -d'/' -f 2)"

    # Create other helpful variables
    userfile="$(echo "${orgname}_${username}" | tr [:upper:] [:lower:] | sed -e 's|\s|_|g')"
    userdir="$TASKDDATA/certs/$userfile"

    # Create org
    if [ ! -d "$TASKDDATA/orgs/$orgname" ]; then
        echo "Creating organization $orgname"
        taskd add org "$orgname" > /dev/null
    fi

    # Add user, capture uuid
    userid="$(taskd add user "$orgname" "$username" | cut -d ' ' -f 4)"

    # Generate user certificates
    cd "$TASKDPKI"

    if [ ! -d "$userdir" ] || $reset_server; then
        echo "Generating client certs for $username ($userid)"
        ./generate.client "$userfile" &> /dev/null
        mkdir -p "$userdir"
        cp "$userfile.cert.pem" "$userdir/"
        cp "$userfile.key.pem" "$userdir/"
    fi

    # Create client installation script
    cat << EOF > "$userdir/setup-$userfile.sh"
#!/bin/sh

mkdir -p "\$HOME/.task"

echo "Installing certificates"

cat << HEREDOC > "\$HOME/.task/ca.cert.pem"
$(cat "$TASKDPKI/ca.cert.pem")
HEREDOC

cat << HEREDOC > "\$HOME/.task/$userfile.cert.pem"
$(cat "$userdir/$userfile.cert.pem")
HEREDOC

cat << HEREDOC > "\$HOME/.task/$userfile.key.pem"
$(cat "$userdir/$userfile.key.pem")
HEREDOC

if which task &> /dev/null; then
    echo "Configuring taskwarrior"
    task config taskd.certificate -- ~/.task/$userfile.cert.pem
    task config taskd.key         -- ~/.task/$userfile.key.pem
    task config taskd.ca          -- ~/.task/ca.cert.pem
    task config taskd.server      -- ${TASKD_HOST}:${TASKD_PORT}
    task config taskd.credentials -- $orgname/$username/$userid
else

cat << HEREDOC
Could not find installed taskwarrior. Install it and, once installed,
run the following commands:

    task config taskd.certificate -- ~/.task/$userfile.cert.pem
    task config taskd.key         -- ~/.task/$username.key.pem
    task config taskd.ca          -- ~/.task/ca.cert.pem
    task config taskd.server      -- ${TASKD_HOST}:${TASKD_PORT}
    task config taskd.credentials -- $orgname/$username/$userid

HEREDOC
fi

cat << HEREDOC
If this is the first time you are syncing with this server, run

    task sync init

otherwise, you can sync normally with

    task sync

HEREDOC
EOF
done
IFS=$OIFS

echo "Starting taskd server"
taskd server --data "$TASKDDATA"
