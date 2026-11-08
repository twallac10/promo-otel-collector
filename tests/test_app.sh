otel_config() { render dev | yq 'select(.kind=="ConfigMap" and .metadata.name=="otel-collector") | .data.relay'; }

test_otel_validate() {
  d=$(mktemp -d); otel_config > "$d/relay.yaml"
  [ -s "$d/relay.yaml" ] || fail "no collector config rendered"
  img=$(render dev | yq 'select(.kind=="Deployment") | .spec.template.spec.containers[0].image')
  chmod -R a+rX "$d" # the image runs as non-root; mktemp -d is 0700 on Linux
  docker run --rm -e MY_POD_IP=127.0.0.1 -v "$d:/cfg:ro" "$img" validate --config=/cfg/relay.yaml
}

test_otel_service_ports() {
  ports=$(render dev | yq 'select(.kind=="Service" and .metadata.name=="otel-collector") | .spec.ports[] | .name + ":" + (.port|tostring)' | tr '\n' ' ')
  for p in otlp-http:4318 metrics:8888 health:13133; do
    echo "$ports" | grep -q "$p" || fail "service lacks $p: $ports"
  done
}

test_otel_tests() {
  hooks=$(render dev | test_hooks | yq 'select(.kind=="Pod") | .metadata.name' | grep -v -- '---' | sort | tr '\n' ' ')
  [ "$hooks" = "otel-collector-test-health otel-collector-test-spans " ] || fail "test pods: $hooks"
}
