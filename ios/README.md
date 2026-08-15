# iOS modules

Phase 1 contains the pure, zero-dependency `BoardCore` Swift package. Run its
fixture-driven tests from the package directory:

```sh
cd ios/BoardCore
swift test
```

The tests read the shared golden vectors from `shared/fixtures/` by walking up
from the test source path. The fixture is deliberately not copied into this
package.
