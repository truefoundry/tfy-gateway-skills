# Fine-Tuning Data Validation

## Data Formats

Training data must be in **JSONL format** (one JSON object per line). Two formats are supported:

### Chat Format (Recommended for Instruction-Tuned Models)

Each line contains a `messages` array with conversation turns:

```jsonl
{"messages": [{"role": "system", "content": "You are a helpful medical assistant."}, {"role": "user", "content": "What are the symptoms of flu?"}, {"role": "assistant", "content": "Common flu symptoms include fever, cough, sore throat, body aches, and fatigue."}]}
{"messages": [{"role": "user", "content": "Explain photosynthesis"}, {"role": "assistant", "content": "Photosynthesis is the process by which plants convert sunlight, water, and CO2 into glucose and oxygen."}]}
```

- `role` must be one of: `system`, `user`, `assistant`
- `system` message is optional but recommended for setting behavior
- Each line must be a complete conversation (can have multiple turns)
- Multi-turn conversations: alternate `user` and `assistant` messages

### Completion Format (For Text Completion Tasks)

Each line has `prompt` and `completion` keys:

```jsonl
{"prompt": "What is the capital of France?", "completion": "The capital of France is Paris."}
{"prompt": "Summarize: The quick brown fox...", "completion": "A fox jumped over a lazy dog."}
```

## Data Validation Checklist

Before launching training, verify:

- [ ] File is valid JSONL (one JSON object per line, no trailing commas)
- [ ] Chat format: each line has a `messages` array with `role` and `content` fields
- [ ] Completion format: each line has `prompt` and `completion` keys
- [ ] No empty `content` or `completion` values
- [ ] Dataset has at least 10 examples (50+ recommended for meaningful fine-tuning)
- [ ] Examples are representative of the target task
- [ ] Total tokens per example do not exceed the model's context window

## Data Validation Script

```python
import json
import sys

def validate_jsonl(filepath):
    errors = []
    line_count = 0
    with open(filepath, 'r') as f:
        for i, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            line_count += 1
            try:
                obj = json.loads(line)
            except json.JSONDecodeError as e:
                errors.append(f"Line {i}: Invalid JSON — {e}")
                continue

            # Chat format
            if "messages" in obj:
                if not isinstance(obj["messages"], list) or len(obj["messages"]) == 0:
                    errors.append(f"Line {i}: 'messages' must be a non-empty list")
                    continue
                for j, msg in enumerate(obj["messages"]):
                    if "role" not in msg or "content" not in msg:
                        errors.append(f"Line {i}, message {j}: missing 'role' or 'content'")
                    elif msg["role"] not in ("system", "user", "assistant"):
                        errors.append(f"Line {i}, message {j}: invalid role '{msg['role']}'")
                    elif not msg["content"].strip():
                        errors.append(f"Line {i}, message {j}: empty content")
            # Completion format
            elif "prompt" in obj and "completion" in obj:
                if not obj["prompt"].strip():
                    errors.append(f"Line {i}: empty prompt")
                if not obj["completion"].strip():
                    errors.append(f"Line {i}: empty completion")
            else:
                errors.append(f"Line {i}: must have 'messages' (chat) or 'prompt'+'completion' (completion)")

    if errors:
        print(f"Found {len(errors)} error(s):")
        for e in errors[:20]:
            print(f"  {e}")
        if len(errors) > 20:
            print(f"  ... and {len(errors) - 20} more")
        return False
    else:
        print(f"Valid JSONL with {line_count} examples.")
        return True

if __name__ == "__main__":
    validate_jsonl(sys.argv[1])
```

## Data Storage Options

| Storage | How to Reference | Notes |
|---------|-----------------|-------|
| **Local file** | Upload as TrueFoundry Artifact first | Recommended for reproducibility |
| **TrueFoundry Artifact** | Artifact FQN | Best option — versioned, tracked |
| **S3 / GCS / Azure Blob** | Pre-signed URL or mounted volume | Use for large datasets already in cloud |
