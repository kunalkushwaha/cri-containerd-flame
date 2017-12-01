FROM golang:1.9 as bench
ARG POWERTEST_REPO=https://github.com/kunalkushwaha/ctr-powertest.git
ARG POWERTEST_COMMIT=HEAD
ARG POWERTEST_BRANCH=master
RUN go get github.com/spf13/cobra
RUN mkdir -p /go/src/github.com/kunalkushwaha && cd /go/src/github.com/kunalkushwaha && git clone -b $POWERTEST_BRANCH $POWERTEST_REPO && cd ctr-powertest && git checkout $POWERTEST_COMMIT
WORKDIR /go/src/github.com/kunalkushwaha/ctr-powertest
RUN go build
ENTRYPOINT ["./ctr-powertest", "-p","cri", "-r","crio","profile"]


FROM golang:1.9 as cri
ARG CNI_VERSION=0.6.0
RUN go get github.com/opencontainers/runc
RUN cp /go/bin/runc /usr/bin/runc
RUN mkdir -p /opt/cni/bin && curl -sSLf https://github.com/containernetworking/plugins/releases/download/v${CNI_VERSION}/cni-plugins-amd64-v${CNI_VERSION}.tgz | tar -zx -C /opt/cni/bin
RUN apt-get update && apt-get install -y socat iptables
RUN apt-get install -y \
  btrfs-tools \
  libassuan-dev \
  libdevmapper-dev \
  libglib2.0-dev \
  libc6-dev \
  libgpgme11-dev \
  libgpg-error-dev \
  libseccomp-dev \
  libselinux1-dev \
  pkg-config \
  go-md2man \
  libapparmor-dev
#TODO: Build skopeo in different stage and copy here
COPY skopeo /usr/bin/skopeo 
RUN mkdir -p /go/src/github.com/kubernetes-incubator
ARG CRIO_REPO=https://github.com/kubernetes-incubator/cri-o.git
ARG CRIO_COMMIT=HEAD
ARG CRIO_BRANCH=v1.9.0-beta.1
RUN cd /go/src/github.com/kubernetes-incubator && git clone -b $CRIO_BRANCH $CRIO_REPO && cd cri-o && git checkout $CRIO_COMMIT
WORKDIR  /go/src/github.com/kubernetes-incubator/cri-o
RUN make install.tools
RUN make BUILD_TAGS="" && make install
RUN make install.config
RUN mkdir -p /etc/cni/net.d
COPY 10-containerd-net.conflist /etc/cni/net.d/
RUN mkdir  /etc/containers 
COPY policy.json /etc/containers/policy.json
COPY cri-c8d-run.sh /
ENTRYPOINT ["/cri-c8d-run.sh", "--profiling", "--profiling-addr=127.0.0.1", "--profiling-port=6060"]
