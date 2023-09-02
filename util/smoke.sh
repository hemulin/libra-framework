#!/bin/bash

echo -e "\n0L: running smoke tests"

if [[ ! -v DIEM ]]
then
    echo $DIEM
    echo "0L: '\$DIEM' source path does not exist,"
    return
fi

export ZAPATOS_BIN_PATH=$DIEM/target/release

unset MRB_PATH
export MRB_PATH=$(cd ./framework/releases/ && pwd -P | xargs -I {} echo "{}/head.mrb")

(cd smoke-tests && ZAPATOS_BIN_PATH=$DIEM/target/release cargo test -- --nocapture)

