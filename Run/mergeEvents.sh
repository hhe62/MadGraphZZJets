#!/bin/bash

exit_on_error() {
    result=$1
    code=$2
    message=$3

    if [ $1 != 0 ]; then
        echo $3
        exit $2
    fi
} 

seed="$1"
nevt01j=$2
nevt2j=$3

sed -n -e "/<LesHouchesEvents/ p" -e "/<header/,/<\/header/ p" -e "/<init>/,/<\/init>/ p" < ${seed}_01j.lhe > 01jHeader
sed -n -e "/<LesHouchesEvents/ p" -e "/<header/,/<\/header/ p" -e "/<init>/,/<\/init>/ p" < ${seed}_2j.lhe > 2jHeader
sed -n "/<event/,/<\/event/ p" < ${seed}_01j.lhe > 01jEvent
sed -n "/<event/,/<\/event/ p" < ${seed}_2j.lhe > 2jEvent
rm combineEventTemp
cat 01jEvent 2jEvent >> combineEventTemp
python mergeHeader.py ||exit_on_error $? 154 "Error merging header--ErrorPattern"
python LHE_select_event.py $seed $nevt01j $nevt2j ||exit_on_error $? 155 "Error merging events body--ErrorPattern"
rm ${seed}.lhe
cat combinedHeader Events_merged.lhe >> ${seed}.lhe
echo "</LesHouchesEvents>" >> ${seed}.lhe
