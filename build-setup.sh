#!/usr/bin/env bash

# exit script if any command fails
set -e
set -o pipefail

RDIR=$(git rev-parse --show-toplevel)

# get helpful utilities
source $RDIR/scripts/utils.sh

common_setup

usage() {
    echo "Usage: ${0} [OPTIONS] [riscv-tools | esp-tools]"
    echo ""
    echo "Helper script to initialize repository that wraps other scripts."
    echo "Sets up conda environment, initializes submodules, and installs toolchain collateral."
    echo ""
    echo "Installation Types"
    echo "  riscv-tools: if set, builds the riscv toolchain (this is also the default)"
    echo "  esp-tools: if set, builds esp-tools toolchain used for the hwacha vector accelerator"
    echo ""
    echo "Options"
    echo "  --help -h              : Display this message"
    echo "  --unpinned-deps -ud    : Use unpinned conda environment"
    echo "  --force -f             : Skip prompt checking for tagged release/conda"
    echo "  --skip-validate        : DEPRECATED: Same functionality as --force"
    echo "  --skip-conda           : Skip conda env creation"
    echo "  --skip-toolchain-extra : Skip building extra RISC-V toolchain collateral (Spike, PK, tests, libgloos)"
    exit "$1"
}

TOOLCHAIN="riscv-tools"
USE_PINNED_DEPS=true
FORCE_FLAG=""
SKIP_CONDA=false
SKIP_TOOLCHAIN=false

# getopts does not support long options, and is inflexible
while [ "$1" != "" ];
do
    case $1 in
        -h | --help )
            usage 3 ;;
        riscv-tools | esp-tools)
            TOOLCHAIN=$1 ;;
        -ud | --unpinned-deps )
            USE_PINNED_DEPS=false ;;
        --force | -f | --skip-validate)
            FORCE_FLAG=$1 ;;
        --skip-conda)
            SKIP_CONDA=true ;;
        --skip-toolchain-extra)
            SKIP_TOOLCHAIN=true ;;
        * )
            error "invalid option $1"
            usage 1 ;;
    esac
    shift
done

if [ "$SKIP_CONDA" = false ]; then
    # note: lock file must end in .conda-lock.yml - see https://github.com/conda-incubator/conda-lock/issues/154
    CONDA_REQS=$RDIR/conda-reqs
    CONDA_LOCK_REQS=$CONDA_REQS/conda-lock-reqs
    LOCKFILE=$CONDA_LOCK_REQS/conda-requirements-$TOOLCHAIN-linux-64.conda-lock.yml

    if [ "$USE_PINNED_DEPS" = false ]; then
        # auto-gen the lockfile
        conda-lock -f $CONDA_REQS/chipyard.yaml -f $CONDA_REQS/$TOOLCHAIN.yaml --lockfile $LOCKFILE
    fi

    # use conda-lock to create env
    conda-lock install -p $RDIR/.conda-env $LOCKFILE

    source $RDIR/.conda-env/etc/profile.d/conda.sh
    conda activate $RDIR/.conda-env
fi

if [ -z "$FORCE_FLAG" ]; then
    if [ -z ${CONDA_DEFAULT_ENV+x} ]; then
        error "ERROR: No conda environment detected. Did you activate the conda environment (e.x. 'conda activate base')?"
        exit 1
    fi
fi

$RDIR/scripts/init-submodules-no-riscv-tools.sh $FORCE_FLAG

if [ "$SKIP_TOOLCHAIN" = false ]; then
    $RDIR/scripts/build-toolchain-extra.sh $FORCE_FLAG $TOOLCHAIN
fi

$RDIR/scripts/gen-tags.sh

TMPDIR=$(pwd)
cd $RDIR/generators/mempress
git apply $RDIR/mempress.patch
cd $TMPDIR
unset TMPDIR

cat << EOT >> env.sh
# line auto-generated by $0
conda activate $RDIR/.conda-env
source $RDIR/scripts/fix-open-files.sh
EOT
