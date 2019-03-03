# Traefik

We use Traefik as the ingress controller. 

## Ingresses

The following annotations can be used on `Ingress` objects:

```yaml
annotations:
traefik.ingress.kubernetes.io/priority: "3"
traefik.ingress.kubernetes.io/rate-limit: |
  extractorfunc: client.ip | request.host | request.header.<header name>
  rateset:
    tenRequestsPerFiveSeconds:
      period: 5s
      average: 10
      burst: 50
    hundredRequestsPerOneMinute:
      period: 60s
      average: 100
      burst: 200
traefik.ingress.kubernetes.io/redirect-entry-point: https
traefik.ingress.kubernetes.io/redirect-permanent: "true"
traefik.ingress.kubernetes.io/request-modifier: "AddPrefix: /users"
traefik.ingress.kubernetes.io/service-weights: |
  service_backend1: 12.50%
  service_backend2: 12.50%
  service_backend3: 75
traefik.ingress.kubernetes.io/whitelist-source-range: "1.2.3.4/32"
ingress.kubernetes.io/browser-xss-filter: "true"
ingress.kubernetes.io/content-security-policy: default-src 'self'
ingress.kubernetes.io/content-type-nosniff: "true"
ingress.kubernetes.io/custom-browser-xss-value: VALUE
ingress.kubernetes.io/custom-frame-options-value: VALUE
ingress.kubernetes.io/frame-deny: "true"
ingress.kubernetes.io/hsts-max-age: "315360000"
ingress.kubernetes.io/hsts-include-subdomains: "true"
ingress.kubernetes.io/hsts-preload: "true"
```

## Services

The following annotations can be used on `Service` objects:

```yaml
annotations:
  traefik.ingress.kubernetes.io/buffering: |
    maxrequestbodybytes: 10485760
    memrequestbodybytes: 2097153
    maxresponsebodybytes: 10485761
    memresponsebodybytes: 2097152
    retryexpression: IsNetworkError() && Attempts() <= 2
  traefik.ingress.kubernetes.io/affinity: "true"
  traefik.ingress.kubernetes.io/circuit-breaker-expression: <expression>
  traefik.ingress.kubernetes.io/responseforwarding-flushinterval: "10ms"
  traefik.ingress.kubernetes.io/load-balancer-method: drr
  traefik.ingress.kubernetes.io/max-conn-amount: "10"
  traefik.ingress.kubernetes.io/max-conn-extractor-func: client.ip
  traefik.ingress.kubernetes.io/session-cookie-name: <NAME>
```
