#!/bin/bash

source $(dirname "$0")/functions.sh

WORKSPACE_DIR=$1

if [ -z "${WORKSPACE_DIR}" ]; then
    rave_print "No workspace provided."
    exit 1
fi

rave_print "Initialize verificatum mixnet..."

EG_WORKSPACE="${WORKSPACE_DIR}/eg"
CONSTANTS="${EG_WORKSPACE}/constants.json"
ELECTION_PARAMS="${EG_WORKSPACE}/election_initialized.json"

VERIFICATUM_WORKSPACE="${WORKSPACE_DIR}/vf"

# extract p g g
P=`cat ${CONSTANTS} | jq -r '.large_prime' | tr '[:upper:]' '[:lower:]'`
Q=`cat ${CONSTANTS} | jq -r '.small_prime' | tr '[:upper:]' '[:lower:]'`
G=`cat ${CONSTANTS} | jq -r '.generator' | tr '[:upper:]' '[:lower:]'`

# generate group description for Verificatum
GROUP=$(vog -gen ModPGroup -roenc -explic ${P} ${G} ${Q} | sed "s/[^:]*:://g")

# convert it to JSON
echo "${GROUP}" | sed "s/[^:]*:://g" > ./_tmp_group_description
GROUP_JSON=`vbt -hex ./_tmp_group_description`
rm ./_tmp_group_description

rave_print "generate verificatum configuration"
MIXER_NAME="MergeMixer"

vmni -prot -sid "FOO" -name ${MIXER_NAME} -nopart 1 -thres 1 \
     -pgroup "${GROUP}" -keywidth "1" ${VERIFICATUM_WORKSPACE}/localProtInfo.xml

# generate mixer info, including private key for signing
vmni -party -name "${MIXER_NAME}" \
     -http http://localhost:8041 \
     -hint localhost:4041 \
     ${VERIFICATUM_WORKSPACE}/localProtInfo.xml ${VERIFICATUM_WORKSPACE}/privInfo.xml ${VERIFICATUM_WORKSPACE}/protInfo.xml

rave_print "extract public key from ElectionGuard"
Y=`cat ${ELECTION_PARAMS} | jq -r '.joint_public_key' | tr '[:upper:]' '[:lower:]'`

rave_print "convert pk to Verificatum JSON"
echo ${GROUP_JSON} | jq --arg g "00$G" --arg y "00$Y" '[., [$g, $y]]' > ${VERIFICATUM_WORKSPACE}/publickey.json

rave_print "convert to Verificatum Bytetree"

vmnc -e -pkey ${VERIFICATUM_WORKSPACE}/protInfo.xml -ini seqjson -outi raw ${VERIFICATUM_WORKSPACE}/publickey.json ${VERIFICATUM_WORKSPACE}/publickey.bt
rave_print "import it"
vmn -setpk ${VERIFICATUM_WORKSPACE}/privInfo.xml ${VERIFICATUM_WORKSPACE}/protInfo.xml ${VERIFICATUM_WORKSPACE}/publickey.bt

# TODO
# WIDTH=34

# convert ciphertexts to V raw format
# vmnc -e -ciphs -width "${WIDTH}"  -ini seqjson -outi raw \
#      ${VERIFICATUM_WORKSPACE}/protInfo.xml ${VERIFICATUM_WORKSPACE}/input-ciphertexts.json ${VERIFICATUM_WORKSPACE}/input-ciphertexts.raw


rave_print "[DONE] Initialize verificatum mixnet in directory ${VERIFICATUM_WORKSPACE}"
