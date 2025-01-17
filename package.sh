#!/bin/sh
rm -rf .release/
mkdir .release
mkdir .release/TalentSequence2
cp *.toc .release/TalentSequence2/
cp *.lua .release/TalentSequence2/
cd .release/ && zip -r TalentSequence2-$(sed '3!d' ../TalentSequence2.toc | awk '{print $3}')-$(git branch | sed -n -e 's/^\* \(.*\)/\1/p').zip . -x ".*" -x "__MACOSX"
rm -rf TalentSequence2