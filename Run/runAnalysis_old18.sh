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


basedir="$(pwd)"
export SCRAM_ARCH=slc7_amd64_gcc700
source /cvmfs/cms.cern.ch/cmsset_default.sh
export HOME="/hdfs/store/user/hhe62/ZZ_jets_old2018_miniAOD/tmpHome" 
echo "Print new home directory:"
echo $HOME

seed=$1
seed2=$((seed+10))
nevt01j=$2
nevt2j=$3
nthd=$4

echo "nThreads: $nthd"
sed -i "s/seedholder/${seed2}/g" madspin_run.dat
sed -i "s/fileholder/${seed}.lhe/g" madspin_run.dat

tar -xf MG5_aMC_v2.6.5.tar.gz || exit_on_error $? 150 "Failed to unpack MadGraph--ErrorPattern"
mv madspin_run.dat MG5_aMC_v2_6_5
rm MG5_aMC_v2.6.5.tar.gz

mkdir unpack2j
mkdir unpack01j

cd unpack2j
tar -xf ../ZZTo4L012j_5f_NLO_FXFX_slc7_amd64_gcc700_CMSSW_10_6_19_tarball.tar.xz #2j gridpack despite the naming

./runcmsgrid.sh $nevt2j $seed 1 ||exit_on_error $? 151 "Error creating LHE events--ErrorPattern"
mv cmsgrid_final.lhe $basedir/${seed}_2j.lhe
#cp $basedir/${seed}_2j.lhe /hdfs/store/user/hhe62/ZZ_jets_old2018_miniAOD/debugLHE

cd ../unpack01j
tar -xf ../ZZTo4L01j_5f_NLO_FXFX_slc7_amd64_gcc700_CMSSW_10_6_19_tarball.tar.xz

./runcmsgrid.sh $nevt01j $seed 1 ||exit_on_error $? 151 "Error creating LHE events--ErrorPattern"
mv cmsgrid_final.lhe $basedir/${seed}_01j.lhe
#cp $basedir/${seed}_01j.lhe /hdfs/store/user/hhe62/ZZ_jets_old2018_miniAOD/debugLHE

cd ..
./mergeEvents.sh $seed $nevt01j $nevt2j ||exit_on_error $? 152 "Error merging events--ErrorPattern"
mv ${seed}.lhe MG5_aMC_v2_6_5 
scramv1 project CMSSW CMSSW_10_6_19
pushd CMSSW_10_6_19/src
eval $(scramv1 runtime -sh)
popd
#source cmssw_setup.sh
#cmssw_setup CMSSW_10_6_19.tar.gz

cd MG5_aMC_v2_6_5
./MadSpin/madspin madspin_run.dat ||exit_on_error $? 153 "Error decaying events--ErrorPattern"
mv ${seed}_decayed.lhe.gz $basedir/${seed}.lhe.gz

cd $basedir
gzip -d ${seed}.lhe.gz

cp _condor_stderr errfile
python examine_printout.py ||exit_on_error $? 157 "Error in printout examination--ErrorPattern"

genEvents=$(cat genEvents.txt)

if [ -r CMSSW_10_2_26/src ] ; then
  echo release CMSSW_10_2_26 already exists
else
  scram p CMSSW CMSSW_10_2_26
fi
cd CMSSW_10_2_26/src
eval $(scram runtime -sh)

mkdir -p Config/GEN/python
mv ../../fragment.py Config/GEN/python
mv ../../${seed}.lhe .
scram b ||exit_on_error $? 159 "Failed to build fragment--ErrorPattern"

cmsDriver.py Config/GEN/python/fragment.py --filein file:${seed}.lhe --fileout file:GEN.root --mc --eventcontent RAWSIM,LHE --datatier GEN-SIM,LHE --conditions 102X_upgrade2018_realistic_v11 --beamspot Realistic25ns13TeVEarly2018Collision --step GEN,SIM --nThreads $nthd --geometry DB:Extended --era Run2_2018 -n $genEvents --no_exec --python_filename GEN_2018_cfg.py 2>&1|| exit_on_error $? 159 "Failed to run Gen config--ErrorPattern"

cmsRun -e -j report0.xml GEN_2018_cfg.py 2>&1 || exit_on_error $? 159 "Failed to run Gen cmsRun--ErrorPattern"

nevt0=$(grep -Po "(?<=<TotalEvents>)(\d*)(?=</TotalEvents>)" report0.xml | tail -n 1)


cmsDriver.py  --python_filename Premix1_cfg.py --eventcontent PREMIXRAW --customise Configuration/DataProcessing/Utils.addMonitoring --datatier GEN-SIM-RAW --fileout file:premix1.root --pileup_input "dbs:/Neutrino_E-10_gun/RunIISummer17PrePremix-PUAutumn18_102X_upgrade2018_realistic_v15-v1/GEN-SIM-DIGI-RAW" --conditions 102X_upgrade2018_realistic_v15 --step DIGI,DATAMIX,L1,DIGI2RAW,HLT:@relval2018 --procModifiers premix_stage2 --geometry DB:Extended --filein file:GEN.root --datamix PreMix --era Run2_2018 --no_exec --mc -n $nevt0 > /dev/null || exit_on_error $? 159 "Failed to run step 1 config--ErrorPattern"

cmsRun -e -j report1.xml Premix1_cfg.py || exit_on_error $? 159 "Failed to run step 1 cmsRun--ErrorPattern"
nevt1=$(grep -Po "(?<=<TotalEvents>)(\d*)(?=</TotalEvents>)" report1.xml | tail -n 1)

cmsDriver.py  --python_filename Premix2_cfg.py --eventcontent AODSIM --customise Configuration/DataProcessing/Utils.addMonitoring --datatier AODSIM --fileout file:premix2.root --conditions 102X_upgrade2018_realistic_v15 --step RAW2DIGI,L1Reco,RECO,RECOSIM,EI --procModifiers premix_stage2 --filein file:premix1.root --era Run2_2018 --runUnscheduled --no_exec --mc -n $nevt1 || exit_on_error $? 159 "Failed to run step 2 config--ErrorPattern"

cmsRun -e -j report2.xml Premix2_cfg.py || exit_on_error $? 159 "Failed to run step 2 cmsRun--ErrorPattern"
nevt2=$(grep -Po "(?<=<TotalEvents>)(\d*)(?=</TotalEvents>)" report2.xml | tail -n 1)

cmsDriver.py  --python_filename miniAOD_cfg.py --eventcontent MINIAODSIM --customise Configuration/DataProcessing/Utils.addMonitoring --datatier MINIAODSIM --fileout file:MiniAOD_final.root --conditions 102X_upgrade2018_realistic_v15 --step PAT --geometry DB:Extended --filein file:premix2.root --era Run2_2018 --runUnscheduled --no_exec --mc -n $nevt2 || exit_on_error $? 159 "Failed to run miniAOD config--ErrorPattern"

cmsRun -e -j report3.xml miniAOD_cfg.py || exit_on_error $? 159 "Failed to run miniAOD cmsRun--ErrorPattern"
nevt3=$(grep -Po "(?<=<TotalEvents>)(\d*)(?=</TotalEvents>)" report3.xml | tail -n 1)
echo "Final miniAOD events: $nevt3"

echo "Final Gen events: $nevt0"
echo "Final step1 events: $nevt1"
echo "Final step2 events: $nevt2"
echo "Final miniAOD events: $nevt3"

cp MiniAOD_final.root /hdfs/store/user/hhe62/ZZ_jets_old2018_miniAOD/miniAODfiles/${seed}_miniAOD.root
