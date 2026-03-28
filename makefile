deploy: ## Build and deploy the application.
	docker compose up -d --remove-orphans --build

migrate: ## Run database migrations.
	docker compose run server rails db:migrate

sync: ## Sync the application to the server
	rsync -av -e "ssh" --exclude='node_modules' --exclude='.git' --exclude='*.log' --exclude='.tmp' --exclude='tmp' --exclude='data' . root@204.168.181.4:~/cowork

connect: ## Connect to the server
	ssh root@204.168.181.4