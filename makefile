deploy: ## Build and deploy the application.
	docker compose up -d --remove-orphans --build

migrate: ## Run database migrations.
	docker compose run --rm server ./bin/rails db:migrate

seed: ## Seed seats and reference data.
	docker compose run --rm server ./bin/rails db:seed

sync: ## Sync the application to the server
	rsync -av -e "ssh" --exclude='node_modules' --exclude='.git' --exclude='*.log' --exclude='.tmp' --exclude='tmp' --exclude='data' . root@204.168.181.4:~/cowork

connect: ## Connect to the server
	ssh root@204.168.181.4

pass: ## Open rails console in the production container
	docker compose exec server ./bin/rails console
seed: ## Seed the database
	docker compose run server ./bin/rails db:seed