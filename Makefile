# working with centos6,7 os

SERVICE=samplepy2
DEPLOY_DIR=/opt/$(SERVICE)
CONFIG_DIR=/etc/$(SERVICE)
SERVICE_PATH=/etc/systemd/system/$(SERVICE).service
SERVICE_ENV_PATH=$(SERVICE_PATH).d/
SERVICE_PATH_CEN6=/etc/init.d/$(SERVICE)
PIPENV_PIPFILE=$(DEPLOY_DIR)/Pipfile
USER = $(shell whoami)
PYENV = $(shell which pyenv)
PIPENV = $(shell which pipenv)
OS_VERSION = $(shell rpm -E %{rhel})

BACKUP_TIME=$(shell date +'%y_%m_%d__%H_%M_%S')
BACKUP_DIR=$(DEPLOY_DIR)_bak_$(BACKUP_TIME)


guide: check_os
	@echo "======================= guide ======================="
	@echo "Call 'make staging' for deploy staging mode"
	@echo "Call 'make product' for deploy product mode"
	@echo "Call 'make backup' for backup before deploy new version"
	@echo "Call 'make env' for install pyenv and pipenv only"
	@echo "Call 'make run' for test run"
	@echo "Call 'make restart' for restart service"
	@echo "Call 'make log' for tailf log from service"

check_os:
ifeq ($(OS_VERSION),6)
	@echo "Run on centos6"
else ifeq ($(OS_VERSION),7)
	@echo "Run on centos7"
else
	@echo "OS is not support!"
	exit 1
endif


checkroot:
ifneq ($(USER),root)
	$(error run by root user only)
else
	@echo "Correct! running by root user"
endif

clean_env:
	pip uninstall -y pipenv 
	rm -rf /root/.pyenv

pyenv: checkroot
	@echo "======================= install env ======================="
	@if ! test -f /root/.pyenv/bin/pyenv; then\
		echo "pyenv not found. prepare to install pyenv";\
		sudo yum install -y @development zlib-devel bzip2 bzip2-devel readline-devel sqlite sqlite-devel openssl-devel xz xz-devel libffi-devel findutils;\
		curl https://pyenv.run | bash ;\
	else \
		echo "pyenv source is installed!";\
	fi

	@if [ "$(PYENV)" = "/root/.pyenv/bin/pyenv" ]; then\
		echo "pyenv is full installed";\
		echo "$(PYENV)" ;\
	else \
		echo '====================== add script to /root/.bashrc before continue ======================';\
		echo 'export PATH="/root/.pyenv/bin:$$PATH"' ;\
		echo 'eval "$$(pyenv init -)"' ;\
		echo 'eval "$$(pyenv virtualenv-init -)"' ;\
		echo '======================== then run this command ========================';\
		echo 'exec $$SHELL -l' ;\
		echo '=======================================================================';\
		exit 1 ;\
	fi

pyenv_4vscode:
	@echo "======================= install env ======================="
	@if ! test -f ~/.pyenv/bin/pyenv; then\
		echo "pyenv not found. prepare to install pyenv";\
		sudo yum install -y @development zlib-devel bzip2 bzip2-devel readline-devel sqlite sqlite-devel openssl-devel xz xz-devel libffi-devel findutils;\
		curl https://pyenv.run | bash ;\
	else \
		echo "pyenv source is installed!";\
	fi

	echo "$(PYENV)" ;\
	echo '====================== add script to ~/.bashrc if not yet ======================';\
	echo 'export PATH="~/.pyenv/bin:$$PATH"' ;\
	echo 'eval "$$(pyenv init -)"' ;\
	echo 'eval "$$(pyenv virtualenv-init -)"' ;\
	echo '======================== then run this command ========================';\
	echo 'exec $$SHELL -l' ;\
	echo '=======================================================================';\

vscode: pyenv_4vscode
	echo "install for vscode finished"

pipenv: pyenv
	@if [ ! -f /usr/local/bin/pipenv ]; then\
		echo "/usr/local/bin/pipenv not found. prepare to install pipenv";\
		pyenv install 2.7.18;\
		pyenv global 2.7.18;\
		pyenv rehash;\
		pip install pipenv;\
	else \
		echo "pipenv is installed already!";\
	fi

	@if [[ -f /bin/pipenv ]]; then\
		ln -fs /bin/pipenv /usr/local/bin/pipenv;\
		echo "symlink pipenv finished " ;\
	fi
	@if [[ -f /root/.pyenv/shims/pipenv ]]; then\
		ln -fs /root/.pyenv/shims/pipenv /usr/local/bin/pipenv;\
		echo "symlink pipenv finished " ;\
	fi


env: pipenv
ifeq ($(OS_VERSION),6)
	@echo "install environment finished!"
else
	yum install -y rsync
	@echo "install environment finished!"
endif

deploy: check_os env
	@echo "=======================deploy agent======================="
	rm -Rf $(DEPLOY_DIR)/*
	mkdir -p $(DEPLOY_DIR)
	rsync -av ./ $(DEPLOY_DIR)/ --exclude=Makefile --exclude=.*

	@echo "=======================install lib dependence by pipenv======================="
	-PIPENV_PIPFILE=$(PIPENV_PIPFILE) pipenv --rm
	PIPENV_PIPFILE=$(PIPENV_PIPFILE) pipenv sync

	@echo "=======================prepare dir for config======================="
	mkdir -p $(CONFIG_DIR)


backup: check_os
ifeq ($(OS_VERSION),7)
	@echo "======================= backup ======================="
	@if [ -d $(DEPLOY_DIR) ]; then\
		mkdir -p "$(BACKUP_DIR)/service";\
		mkdir -p "$(BACKUP_DIR)/config";\
		cp -Rf $(DEPLOY_DIR) $(BACKUP_DIR)/ ;\
 		cp -Rf $(CONFIG_DIR)/* $(BACKUP_DIR)/config ;\
		cp -Rf $(SERVICE_PATH) $(BACKUP_DIR)/service/ ;\
	fi
else
	@echo "======================= backup ======================="
	@if [ -d $(DEPLOY_DIR) ]; then\
		mkdir -p "$(BACKUP_DIR)/service";\
		mkdir -p "$(BACKUP_DIR)/config";\
		cp -Rf $(DEPLOY_DIR) $(BACKUP_DIR)/ ;\
 		cp -Rf $(CONFIG_DIR)/* $(BACKUP_DIR)/config ;\
		cp -Rf $(SERVICE_PATH_CEN6) $(BACKUP_DIR)/service/ ;\
	fi
endif

run:
	PIPENV_PIPFILE=$(PIPENV_PIPFILE) pipenv run python main.py

staging: deploy service
	@echo "======================= copy staging config ======================="
	\cp ./conf/logging.ini $(CONFIG_DIR)/logging.ini
	\cp ./conf/staging.common.ini $(CONFIG_DIR)/common.ini
	\cp ./conf/*.jinja2 $(CONFIG_DIR)/
	# keep current node config if exits
	cp -n ./conf/node.ini $(CONFIG_DIR)/node.ini


product: deploy service
	@echo "======================= copy product config ======================="
	\cp ./conf/logging.ini $(CONFIG_DIR)/logging.ini
	\cp ./conf/product.common.ini $(CONFIG_DIR)/common.ini
	\cp ./conf/*.jinja2 $(CONFIG_DIR)/
	# keep current node config if exits
	cp -n ./conf/node.ini $(CONFIG_DIR)/node.ini


service: check_os
ifeq ($(OS_VERSION),7)
	@echo "======================= install service on centos67: copy systemd service file ======================="
	\cp ./systemd/service.service $(SERVICE_PATH)

	mkdir -p $(SERVICE_ENV_PATH)
	\cp ./systemd/override.conf $(SERVICE_ENV_PATH)/
	systemctl daemon-reload
else
	@echo "======================= install service on centos6: copy init.d service file ======================="
	\cp ./systemd/service.centos6 $(SERVICE_PATH_CEN6)
	sudo chmod +x $(SERVICE_PATH_CEN6)
	chkconfig --add $(SERVICE)
	# fix wrong symlink env
	sudo ln -snf /bin/env /usr/bin/env
endif

restart:
	service $(SERVICE) restart

log:
	tailf /var/log/$(SERVICE).log