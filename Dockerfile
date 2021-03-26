# bump: alpine /FROM alpine:([\d.]+)/ docker:alpine|^3
FROM alpine:3.13.3 as builder
RUN \
    apk add --no-cache \
    bash \
    build-base \
    findutils \
    curl \
    git \
    ninja \
    python2 \
    bsd-compat-headers \
    linux-headers \
    libexecinfo-dev

# bump: shaka-packager /SHAKA_PACKAGER_VERSION=([\d.]+)/ git:https://github.com/google/shaka-packager.git|^2
ARG SHAKA_PACKAGER_VERSION=2.4.3
ARG DEPOT_TOOLS_VERSION=71417ad5d3f9365d523ebd088cb87179a27ceb69

# install depot_tools http://www.chromium.org/developers/how-tos/install-depot-tools
RUN \
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git && \
    cd /depot_tools && \
    git checkout $DEPOT_TOOLS_VERSION
# depot_tools path last so that alpine ninjs is used (depot_tools ninja does not run on alpine atm)
ENV PATH=$PATH:/depot_tools

RUN sed -i \
    '/malloc_usable_size/a \\nstruct mallinfo {\n  int arena;\n  int hblkhd;\n  int uordblks;\n};' \
    /usr/include/malloc.h

ENV GCLIENT_PY3=0
# gpy ninja generator will look at these
ENV CFLAGS="-O3 -static-libgcc -fno-strict-overflow -fstack-protector-all -fPIE"
ENV CXXFLAGS="-O3 -static-libgcc -fno-strict-overflow -fstack-protector-all -fPIE"
ENV LDFLAGS="-static -Wl,-z,relro -Wl,-z,now"
# alpine specific config
ENV GYP_DEFINES="clang=0 use_experimental_allocator_shim=0 use_allocator=none musl=1"

WORKDIR /shaka_packager
RUN gclient config https://www.github.com/google/shaka-packager.git --name=src
RUN gclient sync -r v$SHAKA_PACKAGER_VERSION --no-history
RUN ninja -C src/out/Release

FROM scratch
COPY --from=builder /shaka_packager/src/out/Release/packager /
# sanity test that the binary work in scratch container
RUN ["/packager"]
ENTRYPOINT ["/packager"]
