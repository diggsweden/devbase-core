# Nexus admin request: GitHub API token

Mise registry routing is currently deferred in the organisation configuration.
APT and direct GitHub release downloads remain mirrored; the existing client
`MISE_GITHUB_TOKEN` is retained temporarily. Complete and verify the server-side
setup below before re-enabling mise routing and removing the client token.

## Request

Configure GitHub upstream authentication on the **existing `github-api` raw proxy
repository** in Nexus at `registry.utv.digg.se`.

- Remote URL: `https://api.github.com/`
- Authentication: Bearer token, using the supplied GitHub personal access token
  (PAT) with access to the required public data.
- Purpose: raise the GitHub API quota for mise's release metadata and attestation
  requests. GitHub normally allows 60 anonymous requests per hour per IP and
  5,000 authenticated requests per hour per user.

Keep the repository's existing name and client URL. The existing Sam Gleske-style
`github-proxy` configuration continues handling public release binaries and
checksums without a token. Once mise routing is re-enabled, Devbase clients can
read the mirrors anonymously; the upstream token for the mirror stays in Nexus.

## Configuration through the Nexus REST API

Use Nexus admin credentials for these operations.

1. Retrieve the existing repository configuration:

   ```http
   GET /service/rest/v1/repositories/raw/proxy/github-api
   ```

2. Set its `httpClient.authentication` field to:

   ```json
   {
     "type": "bearerToken",
     "bearerToken": "<GITHUB_PAT>"
   }
   ```

3. Submit the complete repository configuration, preserving all other settings:

   ```http
   PUT /service/rest/v1/repositories/raw/proxy/github-api
   ```

   The JSON above is only the authentication field, not the complete PUT payload.

4. Invalidate the repository cache to clear cached failures and revalidate content.

## Verification by the Nexus admin

- Confirm a fresh upstream request is authenticated and receives the expected
  GitHub API quota. Verify from the Nexus environment; a cached client response
  alone does not establish upstream authentication.
- Confirm routing rules permit the required release metadata and attestation
  paths, including:

  ```text
  /repos/<owner>/<repo>/releases
  /repos/<owner>/<repo>/releases/tags/<tag>
  /repos/<owner>/<repo>/attestations/sha256:<digest>
  ```

- Retry affected metadata and attestation requests through `github-api` with
  anonymous client access. Keep attestation verification enabled.

Authentication addresses the anonymous API quota. It does not resolve malformed
release tags or routing rules that block required paths.

## References

- [Sonatype repository API](https://help.sonatype.com/en/repositories-api.html)
- [GitHub API authentication](https://docs.github.com/en/rest/authentication/authenticating-to-the-rest-api)
- [GitHub API rate limits](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api)
