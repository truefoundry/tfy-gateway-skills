# Pinned Container Image Versions

Single source of truth for all model serving container images. Skills should reference this file instead of hardcoding versions.

**Last updated:** February 2026

## Current Versions

| Framework | Image URI | Version | Released | Check for Updates |
|-----------|-----------|---------|----------|-------------------|
| vLLM | `public.ecr.aws/truefoundrycloud/vllm/vllm-openai:v0.13.0` | v0.13.0 | 2026 | [vLLM Releases](https://github.com/vllm-project/vllm/releases) |
| TGI | `ghcr.io/huggingface/text-generation-inference:2.4.1` | 2.4.1 | 2025 | [TGI Releases](https://github.com/huggingface/text-generation-inference/releases) |
| NVIDIA NIM | `nvcr.io/nim/{model-path}:{version}` | model-specific | — | [NGC Catalog](https://catalog.ngc.nvidia.com) |

## Update Frequency

Container images for model serving frameworks are updated frequently (monthly or more). When deploying, consider checking for newer versions using WebFetch on the release pages above.

## Agent Instructions

- Before using a version from this file, consider running WebFetch on the release page to check if a newer stable version exists.
- If a user requests a specific version, use that instead of these defaults.
- When updating this file, also update the last-updated date.

## Version Selection Guidelines

- **vLLM**: Use latest stable release. Avoid release candidates.
- **TGI**: Use latest stable release from ghcr.io.
- **NIM**: Version depends on model. Check NGC catalog for model-specific versions.
