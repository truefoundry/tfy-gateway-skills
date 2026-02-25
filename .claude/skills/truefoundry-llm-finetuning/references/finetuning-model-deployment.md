# Deploying Fine-Tuned Models

After training completes, the fine-tuned model (or LoRA adapter) is saved as a TrueFoundry Artifact. Deploy it for inference using the `llm-deploy` skill.

## Deploying a LoRA/QLoRA Adapter

For LoRA-based fine-tuning, you have two options:

### Option A: Merge adapter with base model, then deploy

Use the merge script to combine the LoRA adapter with the base model:

```python
# merge_and_upload.py
# Required: pip install torch==2.3.0+cu121 transformers==4.42.3 peft==0.11.1
from peft import PeftModel
from transformers import AutoModelForCausalLM, AutoTokenizer

# Load base model
base_model = AutoModelForCausalLM.from_pretrained("meta-llama/Llama-3.1-8B-Instruct")
tokenizer = AutoTokenizer.from_pretrained("meta-llama/Llama-3.1-8B-Instruct")

# Load and merge adapter
model = PeftModel.from_pretrained(base_model, "/path/to/adapter")
merged_model = model.merge_and_unload()

# Save merged model
merged_model.save_pretrained("/output/merged-model")
tokenizer.save_pretrained("/output/merged-model")
```

Then deploy the merged model using the `llm-deploy` skill as a standard HuggingFace model.

### Option B: Deploy with dynamic adapter loading (vLLM)

vLLM supports loading LoRA adapters at runtime:

```
--model base-model-path --enable-lora --lora-modules adapter-name=/path/to/adapter
```

This is useful for serving multiple fine-tuned variants from the same base model.

## Deploying a Fully Fine-Tuned Model

Deploy directly using the `llm-deploy` skill. The fine-tuned model is a complete model that can be served like any HuggingFace model.
