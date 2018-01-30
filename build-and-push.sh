#!/bin/bash
builder_image="netsil/netsil-builder"
docker build -t ${builder_image} .
docker push ${builder_image}
