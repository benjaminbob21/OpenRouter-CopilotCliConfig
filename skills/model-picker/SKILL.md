---
name: model-picker
description: Present the configured BobPilot OpenRouter models as a numbered picker and provide the exact Copilot `/model` command for the selected model. Use when the user wants to switch models during an existing Copilot CLI session.
---

# BobPilot Model Picker

When invoked, use the interactive `ask_user` tool with these choices so the user can navigate the picker with the arrow keys and select an item. Do not print the list as plain text first.

Choices:
- Nemotron 550B — `nvidia/nemotron-3-ultra-550b-a55b:free`
- Nemotron 3.5 Lightning — `nvidia/nemotron-3.5-lightning:free`
- Laguna S 2.1 — `poolside/laguna-s-2.1:free`
- DeepSeek V4 Flash Latest — `deepseek/deepseek-v4-flash-latest`
- GPT OSS 120B — `openai/gpt-oss-120b`
- DeepSeek V4 Flash — `deepseek/deepseek-v4-flash`
- DeepSeek V4 Flash 0731 — `deepseek/deepseek-v4-flash-0731`
- GPT-5.6 Luna — `openai/gpt-5.6-luna`

Set the question to: `Select a model:`. After the user selects an item, the assistant must respond with **only** the exact command to run:

`/model <full-model-id>`

The skill then concludes; the next invocation of `/model-picker` will start a fresh selection flow. Do not invent aliases, silently substitute another model, or claim that the model was switched. Skills provide conversational instructions; they cannot directly execute Copilot CLI slash commands. The user must submit the generated `/model` command in the session.
