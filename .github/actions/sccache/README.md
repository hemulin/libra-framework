# No config rust caching
## TL;DR
Use this before your rust build with
```
  steps:
    [... you've set up your environemnt; `apt install` etc.]
    - name: enable sccache
      uses: ./.github/actions/sccache
    [... your tests here]
```
## attribution
This idea is based off of @mwestphal's work here: https://github.com/Mozilla-Actions/sccache-action/issues/50#issuecomment-1705992799
## Caveat emptor
Apologies in advance if you need more options, and it didn't work for your workflow.

# Why you are here:
You want a "no config" solution for caching large Rust projects on Github actions runners.

1. You have a fairly large Rust project
2. Your compile cache seems to expire easily, because maybe:
- you have packages that are defined with GitHub urls
- cargo has a known issue with using `mtime` for fingerprinting. And the modification times get changed on git pulls. More here: https://github.com/rust-lang/cargo/issues/6529
- there are system dependencies e.g. `librocksdb` that use .cargo/registry/src see more here: https://github.com/Swatinem/rust-cache/issues/150
- you have edge cases in your compilation: eg. You might have cargo:rerun-if-env in your package or in upstreams
3. `sccache` usually solves your issues, and you tried this already https://github.com/Mozilla-Actions/sccache-action
- But the way the files get stored creates a great many amount of files (it doesn’t not aggregate to a single cache)
- besides being difficulty to manage, this means that you will git Github API rate limits when calling the cache.
4. `sccache` with an `s3` backend works well for you, but sadly using GitHub secrets to store the S3 authentication doesn’t work on pull requests from outside parties. So you can’t use this without exposing the API keys
6. Your last hope is using `sccache` in local mode in the GitHub actions runner, and caching its storage.


## Good news: Option #6 mostly works
- first we check where sccache saves the files.
- we use `github/actions/cache` scripts to restore cache

## A bit annoying
- To increment the cache is clumsy: you rely on fetching any recent cache hit, and then a new cache bundle is created EACH RUN.
- you can just be lazy and let Github's cache expiration policy take care of it.
- Or you can to clean the cache in your workflow with https://github.com/actions/cache/blob/main/tips-and-workarounds.md#force-deletion-of-caches-overriding-default-cache-eviction-policy

## Bad news: sccache doesn't let you prune the storage
- The cache will always be incremental and keep growing.
- This is a limitation of sccache; you can’t selectively expire the cache.
- The documented workaround for this is setting the SCCACHE_RECACHE on a build, which will expire the build.
- Though in GitHub actions it’s probably just easier, to manually delete the cache, and allow it to rebuild.