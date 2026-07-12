# Sona

A communications platform for hospitality businesses and their workers proof of concept

See [task-info](docs/task-info.md) for more information

## Running the app

### Prerequisites

- **Elixir** ~> 1.17 and **Erlang** (via [asdf](https://asdf-vm.com/) or your package manager)
- **PostgreSQL** running locally on port 5432 (with `postgres`/`postgres` user/password — see `config/dev.exs`)
### Quick start

```bash
# 1. Fetch dependencies and set up the database
mix setup

# 2. (Optional) Enable the AI coach feature
export ANTHROPIC_API_KEY=sk-ant-...

# 3. Start the Phoenix server
mix phx.server
```

The app will be available at [http://localhost:4000](http://localhost:4000).

### Troubleshooting

- **Database connection refused** — ensure PostgreSQL is running and the credentials in `config/dev.exs` match your local setup.
- **Port 4000 already in use** — override with `PORT=4001 mix phx.server`.
---

## Product assumptions

Hospitality workers do not often have company computers, and so may only have access to the software on their mobile phones.

This means we need to ensure the product works well on mobile, as the primary means of access.

## Decided direction to explore

Chat (group plus 1-1) is a basic core that needs to be in any POC. Leaning heavily into this would mean adding additional functionality like emoji reactions, threads, announcement only channels and permissions.

I think it is however more interesting and powerful to offer something different than what Whatsapp already does, and so more compelling to have a basic chat (that is expandable in the future), but add ontop of that the belonging piece tailored to the hospitality use case. Of the ideas explored, I think the most compelling piece that would drive frequent adoption of the app is an **AI personalised coach**.

See more reasoning in [market-research](docs/market-research.md)
