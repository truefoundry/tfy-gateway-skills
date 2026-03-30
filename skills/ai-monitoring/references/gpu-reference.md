# GPU Reference

## Available GPU Types

| GPU Type | VRAM | Architecture | Typical Use |
|----------|------|-------------|-------------|
| `T4` | 16 GB | Turing | Inference, small models |
| `A10_4GB` | 4 GB (fractional) | Ampere | Light inference |
| `A10_8GB` | 8 GB (fractional) | Ampere | Medium inference |
| `A10_12GB` | 12 GB (fractional) | Ampere | Medium models |
| `A10_24GB` | 24 GB (full A10) | Ampere | Large inference, fine-tuning |
| `A10G` | 24 GB | Ampere | Similar to A10_24GB |
| `A100_40GB` | 40 GB | Ampere | Large models, training |
| `A100_80GB` | 80 GB | Ampere | Very large models |
| `L4` | 24 GB | Ada Lovelace | Inference optimized |
| `L40S` | 48 GB | Ada Lovelace | Large inference |
| `H100_80GB` | 80 GB | Hopper | Training, large models |
| `H100_94GB` | 94 GB | Hopper | Training, largest models |
| `H200` | 141 GB | Hopper | Next-gen training |

## Model Size to GPU Mapping (Inference, FP16)

| Model Params | Min VRAM (FP16) | Recommended GPU | CPU | Memory |
|-------------|-----------------|-----------------|-----|--------|
| < 1B | ~2 GB | T4 (16 GB) | 4 | 16 GB |
| 1B–3B | ~4–6 GB | T4 or A10_8GB | 4–8 | 32 GB |
| 3B–7B | ~6–14 GB | T4 or A10_24GB | 8–10 | 64 GB |
| 7B–13B | ~14–26 GB | A10_24GB or A100_40GB | 10–12 | 90 GB |
| 13B–30B | ~26–60 GB | A100_40GB or A100_80GB | 12–16 | 128 GB |
| 30B–70B | ~60–140 GB | A100_80GB or H100 (multi-GPU) | 16+ | 200 GB+ |

## QLoRA Fine-Tuning GPU Requirements

| Model Params | Min VRAM | Recommended GPU | CPU | Memory |
|-------------|----------|-----------------|-----|--------|
| < 1B | ~4 GB | T4 (16 GB) | 4 | 16 GB |
| 1B–3B | ~8 GB | T4 (16 GB) | 4–8 | 32 GB |
| 3B–7B | ~16 GB | A10_24GB or T4 (tight) | 8 | 64 GB |
| 7B–13B | ~24–40 GB | A10_24GB or A100_40GB | 8–12 | 90 GB |
| 13B–30B | ~40–80 GB | A100_40GB or A100_80GB | 12–16 | 128 GB |
| 30B–70B | ~80–160 GB | A100_80GB x2 or H100 | 16+ | 256 GB+ |

- **LoRA**: ~1.5x QLoRA VRAM
- **Full fine-tuning**: ~3-4x QLoRA VRAM

## DTYPE Selection

| GPU Family | Recommended DTYPE | Notes |
|-----------|-------------------|-------|
| T4 | `float16` | No bfloat16 support |
| A10/A10G | `float16` or `bfloat16` | Both work |
| A100 | `bfloat16` | Better precision, same speed |
| L4/L40S | `bfloat16` | Ada Lovelace architecture |
| H100/H200 | `bfloat16` | Best precision and speed |

## SDK Usage

```python
from truefoundry.deploy import NvidiaGPU, GPUType, Resources

resources = Resources(
    cpu_request=4, cpu_limit=4,
    memory_request=16384, memory_limit=16384,
    devices=[NvidiaGPU(name=GPUType.T4, count=1)],
)
```

## GPU Discovery

Check available GPUs via the cluster API before presenting options to the user. Not all GPU types are available on every cluster.
