DNMP（Docker + Nginx/Openresty + MySQL5,8 + PHP5,7,8 + Redis + ElasticSearch + MongoDB + RabbitMQ）是一款全功能的**LNMP一键安装程序，支持Arm CPU**。

> 找远程工作，推荐[远程岛](https://yuanchengdao.com/)。


<details>
<summary>项目地址</summary>

- [GitHub 地址](https://github.com/yeszao/dnmp)
- [Gitee 地址](https://gitee.com/yeszao/dnmp)

</details>

<details>
<summary>QQ交流群</summary>

- 1群：**572041090**（已满）
- 2群：**300723526**（已满）
- 3群：**878913761**（已满）
- 4群：**850756381**（有位）
</details>

<details>
<summary>DNMP项目特点</summary>

1. `100%`开源
2. `100%`遵循Docker标准
3. 支持**多版本PHP**共存，可任意切换（PHP5.4、PHP5.6、PHP7.4、PHP8.0、PHP8.2）
4. 支持绑定**任意多个域名**
5. 支持**HTTPS和HTTP/2**
6. **PHP源代码、MySQL数据、配置文件、日志文件**都可在Host中直接修改查看
7. 内置**完整PHP扩展安装**命令
8. 默认支持`pdo_mysql`、`mysqli`、`mbstring`、`gd`、`curl`、`opcache`等常用热门扩展，根据环境灵活配置
9. 可一键选配常用服务：
    - 多PHP版本：PHP5.4、PHP5.6、PHP7.4、PHP8.0、PHP8.2
    - Web服务：Nginx、Openresty
    - 数据库：MySQL5、MySQL8、Redis、memcached、MongoDB、ElasticSearch
    - 消息队列：RabbitMQ
    - 辅助工具：Kibana、Logstash、phpMyAdmin、phpRedisAdmin、AdminMongo
10. 适用于本地开发和集成验证，生产使用需按第 7 节完成安全与高可用加固
11. 镜像来源包括 Docker Hub、Quay 和 GHCR；正式使用前应固定版本或摘要，并完成来源校验与镜像扫描
12. 一次配置，**Windows、Linux、MacOs**皆可用
13. 支持快速安装扩展命令 `install-php-extensions apcu`
14. 支持安装certbot获取免费https用的SSL证书

</details>

# 目录
- [1.目录结构](#1目录结构)
- [2.快速使用](#2快速使用)
    - [2.1 启用 MySQL 主从与 Redis 集群](#21-启用-mysql-主从与-redis-集群)
    - [2.2 启用 CDC 与可观测性扩展](#22-启用-cdc-与可观测性扩展)
- [3.PHP和扩展](#3PHP和扩展)
    - [3.1 切换Nginx使用的PHP版本](#31-切换Nginx使用的PHP版本)
    - [3.2 安装PHP扩展](#32-安装PHP扩展)
    - [3.3 快速安装php扩展](#33-快速安装php扩展)
    - [3.4 Host中使用php命令行（php-cli）](#34-host中使用php命令行php-cli)
    - [3.5 使用composer](#35-使用composer)
- [4.管理命令](#4管理命令)
    - [4.1 服务器启动和构建命令](#41-服务器启动和构建命令)
    - [4.2 添加快捷命令](#42-添加快捷命令)
- [5.使用Log](#5使用log)
    - [5.1 Nginx日志](#51-nginx日志)
    - [5.2 PHP-FPM日志](#52-php-fpm日志)
    - [5.3 MySQL日志](#53-mysql日志)
- [6.数据库管理](#6数据库管理)
    - [6.1 phpMyAdmin](#61-phpmyadmin)
    - [6.2 phpRedisAdmin](#62-phpredisadmin)
- [7.在正式环境中安全使用](#7在正式环境中安全使用)
- [8.常见问题](#8常见问题)
    - [8.1 如何在PHP代码中使用curl？](#81-如何在php代码中使用curl)
    - [8.2 Docker使用cron定时任务](#82-Docker使用cron定时任务)
    - [8.3 Docker容器时间](#83-Docker容器时间)
    - [8.4 如何连接MySQL和Redis服务器](#84-如何连接MySQL和Redis服务器)


## 1.目录结构

```
/
├── data                        数据库数据目录
│   ├── esdata                  ElasticSearch 数据目录
│   ├── mongo                   MongoDB 数据目录
│   ├── mysql                   MySQL8 数据目录
│   ├── mysql-primary           MySQL 主库数据目录
│   ├── mysql-replica           MySQL 从库数据目录
│   ├── kafka                   Kafka KRaft 数据目录
│   ├── mysql5                  MySQL5 数据目录
│   └── redis-cluster           Redis Cluster 数据目录
├── services                    服务构建文件和配置文件目录
│   ├── elasticsearch           ElasticSearch 配置文件目录
│   ├── debezium                Debezium Connector 示例配置目录
│   ├── mysql                   MySQL8 配置文件目录
│   ├── mysql-replication       MySQL 主从配置和初始化脚本目录
│   ├── mysql5                  MySQL5 配置文件目录
│   ├── nginx                   Nginx 配置文件目录
│   ├── php54                   PHP5.4 配置目录
│   ├── php56                   PHP5.6 配置目录
│   ├── php74                   PHP7.4 配置目录
│   ├── php80                   PHP8.0 配置目录
│   ├── php82                   PHP8.2 配置目录
│   └── redis                   Redis 配置目录
├── logs                        日志目录
├── scripts                     本地运维脚本目录
├── docker-compose.mysql-redis.sample.yml  MySQL 主从 / Redis Cluster 扩展示例文件
├── docker-compose.cdc.sample.yml      Kafka / Kafka Connect / Debezium 扩展示例文件
├── docker-compose.observability.sample.yml  Jaeger OTLP 扩展示例文件
├── docker-compose.sample.yml   Docker 服务配置示例文件
├── env.sample                  环境配置示例文件
└── www                         PHP 代码目录
```

## 2.快速使用
### 1. 本地安装
    - `git`
    - `Docker`(系统需为Linux，Windows 10 Build 15063+，或MacOS 10.12+，且必须要`64`位）
    - `Docker Compose v2`（使用 `docker compose` 命令）
### 2. `clone`项目：
    ```
    $ git clone https://github.com/yeszao/dnmp.git
    ```
### 3. 如果主机是 Linux系统，且当前用户不是`root`用户，还需将当前用户加入`docker`用户组：
    ```
    $ sudo gpasswd -a ${USER} docker
    ```
### 4. 拷贝并命名配置文件（Windows系统请用`copy`命令），启动：
    ```
    $ cd dnmp                                           # 进入项目目录
    $ cp env.sample .env                                # 复制环境变量文件。note:安装php扩展请查看文档中的3.2小节
    $ cp docker-compose.sample.yml docker-compose.yml   # 复制 Docker Compose 配置文件。默认启动4个服务：
                                                        # Nginx、PHP8.2、MySQL8和MySQL5.7。要开启更多其他服务，如Redis、
                                                        # PHP5.6、PHP5.4、MongoDB，ElasticSearch等，请删
                                                        # 除服务块前的注释
    $ docker compose up                                 # 启动
    ```
#### 5. 在浏览器中访问：`http://localhost`或`https://localhost`(自签名HTTPS演示)就能看到效果，PHP代码在文件`./www/localhost/index.php`。

### 2.1 启用 MySQL 主从与 Redis 集群
扩展编排文件不会影响默认 DNMP 服务。复制配置后使用脚本启动，脚本会检查数据版本、初始化复制和校验 Redis Cluster 完整拓扑；不要用普通 `docker compose up` 绕过这些检查。

```bash
$ cp docker-compose.mysql-redis.sample.yml docker-compose.mysql-redis.yml
$ scripts/restart-mysql-redis.sh
```

升级已有环境时，先原子同步 `.env` 和新版 sample 到本地未跟踪的 `docker-compose.mysql-redis.yml`，再运行脚本统一收敛；不要在新脚本与旧编排并存时逐个 `docker restart`。脚本会核对 MySQL/Redis 配置摘要接线，旧编排未接入时直接退出。

存量 `.env` 应保留本地密码并逐项合并，不能直接用 `env.sample` 覆盖；同时删除旧 `COMPOSE_FILE`、`REDIS_PASSWORD` 和 `REDIS_CLUSTER_NODE_*_PORT/BUS_PORT`，加入 `DNMP_EXT_HOST_IP`、`DNMP_ADMIN_HOST_IP`、`REDIS_CLUSTER_PASSWORD` 和 `REDIS_CLUSTER_NODE_*_HOST_PORT`。删除 `COMPOSE_FILE` 后，扩展服务统一使用文档中的显式 `-f` 参数和脚本入口，避免普通 `docker compose up` 绕过初始化闭环。

按需修改 `.env` 中以下变量：

- `DNMP_EXT_HOST_IP`：数据端口的宿主机监听地址，默认 `127.0.0.1`。
- `MYSQL_REPLICATION_VERSION`、`MYSQL_PRIMARY_*`、`MYSQL_REPLICA_*`、`MYSQL_REPLICATION_*`
- `REDIS_VERSION`：单节点 Redis 镜像版本
- `REDIS_CLUSTER_VERSION`、`REDIS_CLUSTER_PASSWORD`、`REDIS_CLUSTER_NODE_*_HOST_PORT`

说明：

1. 当前主从示例固定使用 MySQL `8.4.10` LTS。`mysql-replication-init` 会创建最小权限账号、建立 GTID 复制，等待本轮账号 DDL 的 GTID 在从库执行，并确认 IO/SQL 线程、来源、只读状态和延迟。存量密码轮换会先预检 channel，以双密码切换，确认账号 DDL 已到从库并验证新凭据，成功后才移除旧密码；账号已存在 secondary 时不会用第三个未知密码覆盖。若复制账号启用了密码历史或复用间隔，脚本会在改密前拒绝自动轮换，应改走组织内的凭据轮换流程。主从的 `MYSQL_*_ROOT_PASSWORD` 和 `MYSQL_*_ROOT_HOST` 只在 fresh 数据目录初始化时由官方入口应用；存量环境应先用受控 SQL 轮换或收紧 root，再同步 `.env`，仅修改变量会导致健康检查或初始化认证失败。
2. 主库已有存量数据时，脚本不会把历史数据自动补到空从库。必须先用一致性备份、Clone 或等价流程恢复从库，再启用 GTID；仅看到复制线程运行不代表历史数据完整。
3. 每个 MySQL 数据目录都保存 `.dnmp-version`。fresh 启动前还会同时写入 `.dnmp-initializing-version`：可恢复的同版本初始化中断能够安全重试，复制校验成功后才转为正式版本标记；缺少 MySQL 系统库却残留其他数据、单边或版本不匹配的半成品都会 fail-close。旧根目录 `data/mysql-replication.version` 不参与脚本判断，仅保留为人工升级证据，迁移验证完成后可手工删除。
4. 主从单边为空、版本不一致或存量目录未标记时脚本会拒绝启动。完成备份并确认数据已经按官方路径升级、且能由目标镜像正常启动后，才可使用 `ADOPT_MYSQL_REPLICATION_VERSION=1`；该参数不能把不兼容数据变成兼容数据，也不能用于降级。
5. `RESET_MYSQL_REPLICATION=1 scripts/restart-mysql-redis.sh` 会先移除当前 Compose 项目的相关容器，并确认所有固定名容器都已不存在，再清空主从两个实际挂载的数据目录并重建，仅适用于可丢弃的本地数据。无法确认容器已移除时不会删除数据。
6. 从库启用 `read_only`、持久化 `super_read_only` 和 `relay_log_recovery`，主从都要求 `sync_binlog=1`。严格健康检查会把复制停止、来源错误、认证失败、耐久配置漂移或延迟超过 `MYSQL_REPLICATION_MAX_LAG_SECONDS` 的实例标为不健康。该示例不提供自动故障转移；晋升前必须先处理复制一致性，并显式关闭两级只读配置。
7. Redis Cluster 固定为 3 主 3 从、16384 slots。leader 节点的持续健康检查遍历全部 6 个 endpoint 视图，校验 slot 覆盖、重复 owner、迁移状态和 owner layout 一致性；其余节点检查本地拓扑与复制链路。初始化再执行完整 `cluster check`，已有部分拓扑时拒绝重新建群。
8. Redis Cluster 示例固定使用 `8.2.7-alpine`，节点通过官方入口降权为 `redis` 用户。升级已有 RDB/AOF 前仍需备份并验证目标版本；旧数据首次重建容器时会一次性修正 `/data` ownership。Cluster 在 Docker 内网也必须设置非空 `REDIS_CLUSTER_PASSWORD`，Cluster bus 只在 Docker 网络内使用，不发布到宿主机。
9. Redis 节点通告容器 hostname 和内部端口。容器内客户端可直接使用 `redis-cluster-7001:7001` 等地址；宿主机 Cluster 客户端需要解析这些 hostname，并在自定义宿主机端口时配置地址改写。
10. 修改 Redis 固定网段、节点 IP 或拓扑后，使用 `RESET_REDIS_CLUSTER=1 scripts/restart-mysql-redis.sh` 清空实际挂载目录并重新建群。该操作会删除全部本地 Cluster 数据，也会在无法确认固定名容器已移除时拒绝清理。
11. 全局 Compose 解析以及 MySQL 数据/配置、Redis 配置预检通过后，脚本不会无条件停止整组服务；运行阶段 MySQL 与 Redis 独立启动和校验，一侧失败不会阻止另一侧恢复。Redis 启动脚本或基础配置内容变化时，配置摘要会触发一次节点重建；内容未变时重复执行不会重启节点。
12. 如果基础编排中启用了单节点 `redis`，脚本也会确保它已启动。
13. 脚本使用 `/tmp/dnmp-restart-mysql-redis.lock` 串行化预检、RESET、启动、初始化和 marker 收敛；并发调用会直接拒绝。进程被强制终止而留下空锁目录时，确认没有脚本仍在运行后再用 `rmdir` 删除。

### 2.2 启用 CDC 与可观测性扩展
CDC 与可观测性扩展不会影响默认 DNMP 服务。本地 CDC 使用 `mysql-primary` 作为 binlog 来源；默认单节点 `mysql` 关闭了 binlog，不作为 Debezium 数据源。`env.sample` 默认不创建 Debezium 账号，启用 CDC 前必须先在 `.env` 设置独立账号和强密码，再运行初始化脚本。存量环境还要同步 `docker-compose.cdc.yml` 和 `docker-compose.observability.yml` 后再整体重建扩展服务，不能继续使用旧镜像与旧凭据接线。

```bash
$ cp docker-compose.mysql-redis.sample.yml docker-compose.mysql-redis.yml
$ cp docker-compose.cdc.sample.yml docker-compose.cdc.yml
$ cp docker-compose.observability.sample.yml docker-compose.observability.yml
$ scripts/restart-mysql-redis.sh
$ docker compose \
  -f docker-compose.yml \
  -f docker-compose.mysql-redis.yml \
  -f docker-compose.cdc.yml \
  -f docker-compose.observability.yml \
  up -d kafka kafka-connect kafka-ui jaeger
```

按需修改 `.env` 中以下变量：

- `DNMP_EXT_HOST_IP`：MySQL、Redis、Kafka 和 OTLP 数据端口的监听地址，默认 `127.0.0.1`。
- `DNMP_ADMIN_HOST_IP`：Kafka Connect、Kafka UI 和 Jaeger UI 管理端口的监听地址，默认 `127.0.0.1`。
- `MYSQL_DEBEZIUM_USER`、`MYSQL_DEBEZIUM_PASSWORD`：Debezium Connector 使用的独立 MySQL 账号，不复用主从复制账号；默认留空，启用 CDC 时缺失会直接拒绝启动。
- `KAFKA_VERSION`、`KAFKA_HOST_PORT`、`KAFKA_HOST_ADVERTISED_HOST`：宿主机访问 Kafka 时返回给客户端的地址，默认 `127.0.0.1`。
- `DEBEZIUM_CONNECT_VERSION`、`KAFKA_CONNECT_*`：Debezium 3.x 镜像使用 `quay.io/debezium/connect`。
- `KAFKA_UI_VERSION`、`KAFKA_UI_HOST_PORT`：使用维护中的 Kafbat UI 镜像。
- `JAEGER_VERSION`、`JAEGER_OTLP_*`、`JAEGER_UI_HOST_PORT`

创建或更新 Debezium Connector：
```bash
$ curl -i -X PUT \
  -H 'Content-Type: application/json' \
  --data @services/debezium/connectors/admin-mysql-source.sample.json \
  http://127.0.0.1:8083/connectors/admin-mysql-source/config
```

常用检查：
```bash
$ curl http://127.0.0.1:8083/connectors
$ curl http://127.0.0.1:8083/connectors/admin-mysql-source/status
```

本地访问入口：

- Kafka Connect：`http://127.0.0.1:8083`
- Kafka UI：`http://127.0.0.1:8088`
- Jaeger UI：`http://127.0.0.1:16686`
- OTLP gRPC：`127.0.0.1:4317`
- OTLP HTTP：`127.0.0.1:4318`

说明：

1. 当前示例固定使用 Kafka `4.3.1`、Debezium Connect `3.6.0.Final`、Kafbat UI `v1.5.0` 和 Jaeger `2.19.0`。镜像版本与配置变更应显式升级，不使用浮动 minor tag。
2. Connector JSON 只维护采集范围和 topic 等契约；账号密码唯一来源是 `.env`，通过 Kafka ConfigProvider 在 worker 内解析。Connect REST 返回的应是 `${env:MYSQL_DEBEZIUM_PASSWORD}` 占位符，不应出现真实密码。
3. 请按实际库表修改 `database.include.list`、`table.include.list` 和 `topic.prefix`。每个 Connector 必须使用独立的 schema history topic；`database.server.id` 也必须在 MySQL 服务器及所有复制客户端中全局唯一。
4. 示例使用 `snapshot.mode=no_data`，只采集表结构和后续 binlog，不回填历史数据；同时关闭 delete tombstone 空消息。
5. `MYSQL_REPLICATION_USER` 只用于复制；`MYSQL_DEBEZIUM_USER` 被收敛到 `SELECT`、`RELOAD`、`SHOW DATABASES`、`REPLICATION SLAVE`、`REPLICATION CLIENT` 权限。
6. Kafka Connect 内部 topic 和 schema history 持久化到 `data/kafka`。Kafka 4.3.1 以 UID/GID `1000` 运行，`kafka-data-check` 会在 broker 启动前检查整个数据树的 owner 和写权限；原生 Linux 或恢复备份后应先确认路径正确，再执行 `sudo chown -R 1000:1000 data/kafka` 并确保 owner 可写，不能让 broker 在权限错误下反复重启。
7. 从 Kafka 3.9 升级到 4.3 前，应按[官方升级说明](https://kafka.apache.org/43/getting-started/upgrade/)优雅停止 Connector、Connect 和 Kafka，并备份 `data/kafka`；先切换二进制并验证业务，再在 Kafka 容器中执行 `kafka-features.sh --bootstrap-server kafka:9092 upgrade --release-version 4.3`。feature finalize 前保留二进制回滚窗口，finalize 后不可降级；存量集群 ID 也不能更换。
8. 从 Debezium 3.2 升级到 3.6 前，应按[官方升级说明](https://debezium.io/releases/3.6/release-notes#upgrading)优雅停止 Connector，并保留 offset、config 和 schema history；旧匿名卷需要先迁移，否则只能接受本地消息和 Connector 状态重新初始化。
9. 修改 `MYSQL_DEBEZIUM_PASSWORD` 后，先运行 `scripts/restart-mysql-redis.sh` 更新 MySQL 账号，再重建 `kafka-connect` 并重新执行 PUT。旧明文配置可能仍留在 compacted config topic 的历史 segment 中，因此从旧配置升级时必须轮换密码。
10. 清空或修改 `MYSQL_DEBEZIUM_USER` 只会停止创建或改用新账号，不会自动撤销旧账号。确认旧 Connector 已停止且无人使用后，应通过受控 SQL 对旧账号执行 `DROP USER` 或撤权，并等待该 DDL 同步到从库。
11. Kafka、Connect、Kafka UI 和 Jaeger 均限制 `json-file` 日志大小；Kafka 检查 metadata，Connect 同时检查 REST 与 broker，Kafka UI 检查真实 broker API，Jaeger 检查服务状态。
12. 宿主机应用使用 `127.0.0.1:29092` 和 `127.0.0.1:4317`；同一 Compose 网络内的容器使用 `kafka:9092` 和 `jaeger:4317`。修改连接端点后，应按应用自身的配置生效边界决定是否重启。
13. `DNMP_ADMIN_HOST_IP` 对应的管理服务没有内置公网鉴权。需要远程访问时必须放在受控内网或鉴权代理之后。

## 3.PHP和扩展
### 3.1 切换Nginx使用的PHP版本
首先，需要启动其他版本的PHP，比如PHP5.4，那就先在`docker-compose.yml`文件中删除PHP5.4前面的注释，再启动PHP5.4容器。

PHP5.4启动后，打开Nginx 配置，修改`fastcgi_pass`的主机地址，由`php82`改为`php54`，如下：
```
    fastcgi_pass   php82:9000;
```
为：
```
    fastcgi_pass   php54:9000;
```
其中 `php82` 和 `php54` 是`docker-compose.yml`文件中的服务名称。

最后，**重启 Nginx** 生效。
```bash
$ docker exec -it nginx nginx -s reload
```
这里两个`nginx`，第一个是容器名，第二个是容器中的`nginx`程序。


### 3.2 安装PHP扩展
PHP的很多功能都是通过扩展实现，而安装扩展是一个略费时间的过程，
所以，除PHP内置扩展外，在`env.sample`文件中我们仅默认安装少量扩展，
如果要安装更多扩展，请打开你的`.env`文件修改如下的PHP配置，
增加需要的PHP扩展：
```bash
PHP82_EXTENSIONS="pdo_mysql opcache redis"  # PHP 8.2 扩展使用空格分隔
PHP54_EXTENSIONS=opcache,redis               # PHP 5.4 扩展使用英文逗号分隔
```
然后重新build PHP镜像。
```bash
docker compose build php82
```
可用的扩展请看同文件的`env.sample`注释块说明。

### 3.3 快速安装php扩展
1.进入容器:

```sh
docker exec -it php82 /bin/sh

install-php-extensions apcu 
```
2.支持快速安装扩展列表
## Supported PHP extensions

<!-- START OF EXTENSIONS TABLE -->
<!-- ########################################################### -->
<!-- #                                                         # -->
<!-- #  DO NOT EDIT THIS TABLE: IT IS GENERATED AUTOMATICALLY  # -->
<!-- #                                                         # -->
<!-- #  EDIT THE data/supported-extensions FILE INSTEAD        # -->
<!-- #                                                         # -->
<!-- ########################################################### -->
| Extension | PHP 8.5 | PHP 8.4 | PHP 8.3 | PHP 8.2 | PHP 8.1 | PHP 8.0 | PHP 7.4 | PHP 7.3 | PHP 7.2 | PHP 7.1 | PHP 7.0 | PHP 5.6 | PHP 5.5 |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| amqp | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| apcu | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| apcu_bc |  |  |  |  |  |  | &check; | &check; | &check; | &check; | &check; |  |  |
| ast | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |
| bcmath | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| bitset | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| blackfire | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| brotli | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |
| bz2 | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| calendar | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| cassandra[*](#special-requirements-for-cassandra) | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |  |  |
| cmark |  |  |  |  |  |  | &check; | &check; | &check; | &check; | &check; |  |  |
| csv | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |  |  |  |
| dba | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| ddtrace[*](#special-requirements-for-ddtrace) | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |
| decimal | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |
| ds | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |
| ecma_intl[*](#special-requirements-for-ecma_intl) |  |  | &check; | &check; |  |  |  |  |  |  |  |  |  |
| enchant | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| ev | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| event | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| excimer | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |  |
| exif | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| ffi | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |  |  |  |  |
| ftp | &check; | &check; | &check; | &check; |  |  |  |  |  |  |  |  |  |
| gd | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| gearman |  | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| geoip |  |  |  |  |  |  | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| geos[*](#special-requirements-for-geos) |  | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| geospatial | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| gettext | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| gmagick |  | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| gmp | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| gnupg | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| grpc | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| http | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| igbinary | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| imagick | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| imap | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| inotify | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| interbase |  |  |  |  |  |  |  | &check; | &check; | &check; | &check; | &check; | &check; |
| intl | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| ion | &check; | &check; | &check; | &check; | &check; |  |  |  |  |  |  |  |  |
| ioncube_loader |  | &check; | &check; | &check; | &check; |  | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| ip2location | &check; | &check; | &check; | &check; | &check; | &check; |  |  |  |  |  |  |  |
| jsmin |  |  |  |  |  |  | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| json_post | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| jsonpath | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |  |  |  |  |
| judy[*](#special-requirements-for-judy) | &check; | &check; | &check; | &check; | &check; | &check; |  |  |  |  |  |  |  |
| ldap | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| luasandbox | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| lz4[*](#special-requirements-for-lz4) | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |
| lzf | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| mailparse | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| maxminddb | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |  |  |
| mcrypt | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| md4c | &check; | &check; | &check; | &check; | &check; | &check; |  |  |  |  |  |  |  |
| memcache |  | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| memcached | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| memprof[*](#special-requirements-for-memprof) | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| mongo |  |  |  |  |  |  |  |  |  |  |  | &check; | &check; |
| mongodb | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| mosquitto |  |  |  |  |  |  | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| msgpack | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| mssql |  |  |  |  |  |  |  |  |  |  |  | &check; | &check; |
| mysql |  |  |  |  |  |  |  |  |  |  |  | &check; | &check; |
| mysqli | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| newrelic |  | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |
| nsq |  | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |
| oauth | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| oci8 | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| odbc | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| opcache | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| opencensus |  |  | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |
| openswoole | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |  |  |
| opentelemetry | &check; | &check; | &check; | &check; | &check; | &check; |  |  |  |  |  |  |  |
| operator | &check; | &check; | &check; | &check; |  |  |  |  |  |  |  |  |  |
| parallel[*](#special-requirements-for-parallel) | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |  |
| parle[*](#special-requirements-for-parle) |  | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |
| pcntl | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| pcov | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |
| pdo_dblib | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| pdo_firebird | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| pdo_mysql | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| pdo_oci | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |
| pdo_odbc | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| pdo_pgsql | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| pdo_snowflake[*](#special-requirements-for-pdo_snowflake) |  | &check; | &check; | &check; | &check; |  |  |  |  |  |  |  |  |
| pdo_sqlsrv | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |
| pgsql | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| phalcon |  | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |  |  |
| php_trie |  | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |  |  |  |
| phpy[*](#special-requirements-for-phpy) | &check; | &check; | &check; | &check; | &check; |  |  |  |  |  |  |  |  |
| pkcs11 | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |  |  |  |  |
| pq | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |
| propro |  |  |  |  |  |  | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| protobuf | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| pspell | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| psr | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| pthreads[*](#special-requirements-for-pthreads) |  |  |  |  |  |  |  |  |  |  | &check; | &check; | &check; |
| raphf | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| rdkafka | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| recode |  |  |  |  |  |  |  | &check; | &check; | &check; | &check; | &check; | &check; |
| redis | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| relay | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |  |  |  |  |
| saxon[*](#special-requirements-for-saxon) | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |
| seasclick[*](#special-requirements-for-seasclick) | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| seaslog |  |  | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| shmop | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| simdjson[*](#special-requirements-for-simdjson) | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |  |
| smbclient | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| snappy | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| snmp | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| snuffleupagus | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |
| soap | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| sockets | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| sodium[*](#special-requirements-for-sodium) |  |  |  |  |  |  |  |  |  | &check; | &check; | &check; |  |
| solr | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| sourceguardian | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| spx | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| sqlsrv[*](#special-requirements-for-sqlsrv) | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |
| ssh2 | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| stomp |  | &check; | &check; | &check; |  |  | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| swoole |  | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| sybase_ct |  |  |  |  |  |  |  |  |  |  |  | &check; | &check; |
| sync |  | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| sysvmsg | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| sysvsem | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| sysvshm | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| tensor |  |  |  | &check; | &check; | &check; | &check; | &check; | &check; |  |  |  |  |
| tideways |  | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| tidy | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| timezonedb | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| translit | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| uopz |  |  | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| uploadprogress | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| uuid | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| uv | &check; | &check; | &check; | &check; | &check; | &check; |  |  |  |  |  |  |  |
| vips[*](#special-requirements-for-vips) | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |
| vld | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| wddx |  |  |  |  |  |  |  | &check; | &check; | &check; | &check; | &check; | &check; |
| wikidiff2[*](#special-requirements-for-wikidiff2) | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |  |
| xattr | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| xdebug | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| xdiff | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| xhprof | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| xlswriter | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |
| xmldiff | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| xmlrpc | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| xpass[*](#special-requirements-for-xpass) | &check; | &check; | &check; | &check; | &check; | &check; |  |  |  |  |  |  |  |
| xsl | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| yac | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |
| yaml | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| yar | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| zephir_parser | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |  |  |
| zip | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| zmq |  | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| zookeeper | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |
| zstd | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; | &check; |

*Number of supported extensions: 159*

此扩展来自[https://github.com/mlocati/docker-php-extension-installer](https://github.com/mlocati/docker-php-extension-installer)
参考示例文件

### 3.4 Host中使用php命令行（php-cli）

1. 参考[bash.alias.sample](bash.alias.sample)示例文件，将对应 php cli 函数拷贝到主机的 `~/.bashrc`文件。
2. 让文件起效：
    ```bash
    source ~/.bashrc
    ```
3. 然后就可以在主机中执行php命令了：
    ```bash
    ~ php -v
    PHP 8.2.x (cli)
    Copyright (c) The PHP Group
    Zend Engine v4.2.x, Copyright (c) Zend Technologies
    ```
### 3.5 使用composer
**方法1：主机中使用composer命令**
1. 确定composer缓存的路径。比如，我的dnmp下载在`~/dnmp`目录，那composer的缓存路径就是`~/dnmp/data/composer`。
2. 参考[bash.alias.sample](bash.alias.sample)示例文件，将对应 php composer 函数拷贝到主机的 `~/.bashrc`文件。
    > 这里需要注意的是，示例文件中的`~/dnmp/data/composer`目录需是第一步确定的目录。
3. 让文件起效：
    ```bash
    source ~/.bashrc
    ```
4. 在主机的任何目录下就能用composer了：
    ```bash
    cd ~/dnmp/www/
    composer create-project yeszao/fastphp project --no-dev
    ```
5. （可选）第一次使用 composer 会在 `~/dnmp/data/composer` 目录下生成一个**config.json**文件，可以在这个文件中指定国内仓库，例如：
    ```json
    {
        "config": {},
        "repositories": {
            "packagist": {
                "type": "composer",
                "url": "https://mirrors.aliyun.com/composer/"
            }
        }
    }

    ```
**方法二：容器内使用composer命令**

还有另外一种方式，就是进入容器，再执行`composer`命令，以PHP8.2容器为例：
```bash
docker exec -it php82 /bin/sh
cd /www/localhost
composer update
```
    
## 4.管理命令
### 4.1 服务器启动和构建命令
如需管理服务，请在命令后面加上服务器名称，例如：
```bash
$ docker compose up                         # 创建并且启动所有容器
$ docker compose up -d                      # 创建并且后台运行方式启动所有容器
$ docker compose up nginx php82 mysql       # 创建并且启动 nginx、php82、mysql 容器
$ docker compose up -d nginx php82 mysql    # 创建并且后台启动 nginx、php82、mysql 容器

# 扩展服务命令统一使用 docker compose；MySQL 主从和 Redis Cluster 走脚本入口，避免绕过初始化闭环。
$ scripts/restart-mysql-redis.sh            # 启动或收敛 MySQL 主从、单节点 Redis（如已启用）和 Redis Cluster
$ RESET_MYSQL_REPLICATION=1 scripts/restart-mysql-redis.sh
                                             # 清空本地 MySQL 主从数据并重建
$ RESET_REDIS_CLUSTER=1 scripts/restart-mysql-redis.sh
                                             # 清空本地 Redis Cluster 数据并重新建群
$ docker compose -f docker-compose.yml -f docker-compose.mysql-redis.yml -f docker-compose.cdc.yml -f docker-compose.observability.yml up -d kafka kafka-connect kafka-ui jaeger
                                             # 启动 CDC 与可观测性扩展

$ docker compose start php82                # 启动服务
$ docker compose stop php82                 # 停止服务
$ docker compose -f docker-compose.yml -f docker-compose.mysql-redis.yml stop mysql-primary mysql-replica redis-cluster-7001 redis-cluster-7002 redis-cluster-7003 redis-cluster-7004 redis-cluster-7005 redis-cluster-7006
                                             # 停止 MySQL 主从和 Redis Cluster
$ docker compose -f docker-compose.yml -f docker-compose.mysql-redis.yml stop redis
                                             # 仅在基础编排已启用单节点 Redis 时执行
$ docker compose -f docker-compose.yml -f docker-compose.mysql-redis.yml -f docker-compose.cdc.yml -f docker-compose.observability.yml stop kafka-ui kafka-connect kafka jaeger
                                             # 停止 CDC 与可观测性扩展
$ docker compose restart php82              # 重启服务
$ docker compose build php82                # 构建或者重新构建服务

$ docker compose rm -s php82                # 停止并删除 php82 容器
$ docker compose down                       # 停止并删除基础编排中的容器和网络
```

### 4.2 添加快捷命令
在开发的时候，我们可能经常使用`docker exec -it`进入到容器中，把常用的做成命令别名是个省事的方法。

首先，在主机中查看可用的容器：
```bash
$ docker ps           # 查看所有运行中的容器
$ docker ps -a        # 所有容器
```
输出的`NAMES`那一列就是容器名称；使用默认配置时是`nginx`、`php82`、`mysql`和`mysql5`。

然后，打开`~/.bashrc`或者`~/.zshrc`文件，加上：
```bash
alias dnginx='docker exec -it nginx /bin/sh'
alias dphp='docker exec -it php82 /bin/sh'
alias dphp56='docker exec -it php56 /bin/sh'
alias dphp54='docker exec -it php54 /bin/sh'
alias dmysql='docker exec -it mysql /bin/bash'
alias dredis='docker exec -it redis /bin/sh'
```
下次进入容器就非常快捷了，如进入php容器：
```bash
$ dphp
```

### 4.3 查看docker网络
```sh
ifconfig docker0
```
用于填写`extra_hosts`容器访问宿主机的`hosts`地址

## 5.使用Log

Log文件生成的位置依赖于conf下各log配置的值。

### 5.1 Nginx日志
Nginx日志是我们用得最多的日志，所以我们单独放在根目录`logs/nginx`下。

`logs/nginx`会映射到Nginx容器的`/var/log/nginx`目录，所以在Nginx配置文件中，需要把日志输出到`/var/log/nginx`目录，如：
```
error_log  /var/log/nginx/nginx.localhost.error.log  warn;
```


### 5.2 PHP-FPM日志
大部分情况下，PHP-FPM的日志都会输出到Nginx的日志中，所以不需要额外配置。

另外，建议直接在PHP中打开错误日志：
```php
error_reporting(E_ALL);
ini_set('error_reporting', 'on');
ini_set('display_errors', 'on');
```

如果确实需要，可按一下步骤开启（在容器中）。

1. 进入容器，创建日志文件并修改权限：
    ```bash
    $ docker exec -it php82 /bin/sh
    $ mkdir -p /var/log/php
    $ cd /var/log/php
    $ touch php-fpm.error.log
    $ chmod a+w php-fpm.error.log
    ```
2. 主机上打开并修改PHP-FPM的配置文件`services/php82/php-fpm.conf`，找到如下一行，删除注释，并改值为：
    ```
    php_admin_value[error_log] = /var/log/php/php-fpm.error.log
    ```
3. 重启PHP-FPM容器。

### 5.3 MySQL日志
因为MySQL容器中的MySQL使用的是`mysql`用户启动，它无法自行在`/var/log`下的增加日志文件。所以，我们把MySQL的日志放在宿主机挂载目录中，对应容器中的`/var/log/mysql/`目录。单机模式默认是`./logs/mysql`，主从模式分别是`./logs/mysql-primary`和`./logs/mysql-replica`。
```bash
slow-query-log-file     = /var/log/mysql/mysql.slow.log
log-error               = /var/log/mysql/mysql.error.log
```
以上是mysql.conf中的日志文件的配置。



## 6.数据库管理
本项目默认在`docker-compose.yml`中不开启了用于MySQL在线管理的*phpMyAdmin*，以及用于redis在线管理的*phpRedisAdmin*，可以根据需要修改或删除。

### 6.1 phpMyAdmin
phpMyAdmin容器映射到主机的端口地址是：`8080`，所以主机上访问phpMyAdmin的地址是：
```
http://localhost:8080
```

MySQL连接信息：
- host：默认是 `mysql`；如需管理主从，请先把本地 Compose 中的 `PMA_HOST` 改为 `mysql-primary` 或 `mysql-replica`
- port：`3306`
- username：（手动在phpmyadmin界面输入）
- password：（手动在phpmyadmin界面输入）

### 6.2 phpRedisAdmin
phpRedisAdmin容器映射到主机的端口地址是：`8081`，所以主机上访问phpRedisAdmin的地址是：
```
http://localhost:8081
```

Redis连接信息如下：
- host: `redis`
- port: `6379`

当前 phpRedisAdmin 示例只接入单节点 Redis，不支持本分支的鉴权 Cluster 接线；管理 Redis Cluster 应使用支持 Cluster、密码认证和地址改写的客户端。


## 7.在正式环境中安全使用
要在正式环境中使用，请：
1. 在php.ini中关闭XDebug调试
2. 增强MySQL数据库访问的安全策略
3. 增强redis访问的安全策略
4. MySQL 主从、Redis Cluster、Kafka、Kafka Connect、Kafka UI 和 Jaeger 扩展是生产规范加固的本地开发/集成验证样例，不是真实生产高可用架构。端口默认只绑定 `127.0.0.1`，不要直接暴露到公网。
5. 生产环境应替换全部示例密码，限制 root 和服务账号来源。`DNMP_EXT_HOST_IP` 只控制数据端口，`DNMP_ADMIN_HOST_IP` 控制无内置公网鉴权的管理端口；远程管理入口必须放在受控内网或鉴权代理之后。
6. MySQL 主从和 Redis Cluster 都在单宿主机上，无法抵御宿主机故障。生产环境还需要跨故障域部署、备份恢复演练、监控告警、容量规划和明确的故障转移流程。
7. Redis 密码不加密网络流量；生产环境还需要网络隔离或 TLS、ACL、持久化与淘汰策略评估，不能照搬本地固定 IP 拓扑。
8. Kafka 示例使用 PLAINTEXT 单 broker KRaft；生产环境应启用多 broker、高可用副本、ACL/SASL/TLS，并独立规划 Connect 内部 topic、容量和保留策略。
9. Debezium Quay 镜像面向测试和评估。生产部署应使用经过组织安全基线验证的构建、secret 管理、升级回滚和 connector 监控。
10. Jaeger 示例使用内存存储，仅适合本地调试；生产环境应使用持久化后端、采样策略、鉴权入口和资源限额。
11. MySQL 复制和 Debezium 示例未启用 TLS，只适用于受控的本地 Docker 网络；跨主机部署必须校验服务端证书并加密复制与 CDC 链路。


## 8 常见问题
### 8.1 如何在PHP代码中使用curl？
参考这个issue：[https://github.com/yeszao/dnmp/issues/91](https://github.com/yeszao/dnmp/issues/91)

### 8.2 Docker使用cron定时任务 
[Docker使用cron定时任务](https://www.awaimai.com/2615.html)

### 8.3 Docker容器时间
容器时间在.env文件中配置`TZ`变量，所有支持的时区请看[时区列表·维基百科](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)或者[PHP所支持的时区列表·PHP官网](https://www.php.net/manual/zh/timezones.php)。

### 8.4 如何连接MySQL和Redis服务器
这要分两种情况，

第一种情况，在**PHP代码中**。
```php
// 连接MySQL
$dbh = new PDO('mysql:host=mysql;dbname=mysql', 'root', '123456');

// 连接Redis
$redis = new Redis();
$redis->connect('redis', 6379);
```
如果启用了 MySQL 主从和 Redis Cluster，则可以这样连接：
```php
// 连接 MySQL 主库 / 从库
$primary = new PDO('mysql:host=mysql-primary;dbname=mysql', 'root', '123456');
$replica = new PDO('mysql:host=mysql-replica;dbname=mysql', 'root', '123456');

// 连接 Redis Cluster
$cluster = new RedisCluster(NULL, [
    'redis-cluster-7001:7001',
    'redis-cluster-7002:7002',
    'redis-cluster-7003:7003',
], 0, 0, false, '123456');
```
因为容器与容器是`expose`端口联通的，而且在同一个`networks`下，所以连接的`host`参数直接用容器名称，`port`参数就是容器内部的端口。更多请参考[《docker-compose ports和expose的区别》](https://www.awaimai.com/2138.html)。

第二种情况，**在主机中**通过**命令行**或者**Navicat**等工具连接。主机要连接mysql和redis的话，要求容器必须经过`ports`把端口映射到主机了。以 mysql 为例，`docker-compose.yml`文件中有这样的`ports`配置：`3306:3306`，就是主机的3306和容器的3306端口形成了映射，所以我们可以这样连接：
```bash
$ mysql -h127.0.0.1 -uroot -p123456 -P3306
$ redis-cli -h127.0.0.1
```
这里`host`参数不能用localhost是因为它默认是通过sock文件与mysql通信，而容器与主机文件系统已经隔离，所以需要通过TCP方式连接，所以需要指定IP。
如果启用了 MySQL 主从，则主机可以分别连接 `3307`（主库）和 `3308`（从库）。如果启用了 Redis Cluster，容器内应用建议使用 `redis-cluster-7001:7001` 等容器名访问。宿主机上的 Cluster 客户端会收到 `redis-cluster-700N` endpoint，并可能读取到 `172.30.0.x` 固定 IP 元数据；需要在 hosts 中把 `redis-cluster-7001` ~ `redis-cluster-7006` 指向 `127.0.0.1`，或使用客户端的地址改写能力，把集群通告地址映射到 `127.0.0.1:7001` 等宿主机端口。

### 8.5 容器内的php如何连接宿主机MySQL
1.宿主机执行`ifconfig docker0`得到`inet`就是要连接的`ip`地址
```sh
$ ifconfig docker0
docker0: flags=4099<UP,BROADCAST,MULTICAST>  mtu 1500
        inet 172.17.0.1  netmask 255.255.0.0  broadcast 172.17.255.255
        ...
```
2.运行宿主机Mysql命令行
```mysql
 mysql>GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '123456' WITH GRANT OPTION;
 mysql>flush privileges;
// 其中各字符的含义：
// *.* 对任意数据库任意表有效
// "root" "123456" 是数据库用户名和密码
// '%' 允许访问数据库的IP地址，%意思是任意IP，也可以指定IP
// flush privileges 刷新权限信息
```

3.接着直接php容器使用`172.0.17.1:3306`连接即可

### 8.6 SQLSTATE[HY000] [1130] Host '172.19.0.2' is not allowed to connect to this MySQL server
1. 目前使用mysql-server `8.0.28`以上的版本,php版本需要`7.4.7`以上才能连接

### 8.7 Docker是如何生成容器名
[在不指定容器名称时,是如何生成容器名](https://pet2cattle.com/2022/08/docker-container-names-generator)


## 感谢 Navicat 对开源项目的赞助
[![navicat](https://s1.locimg.com/2024/09/12/e6e96ae680447.png)](https://www.navicat.com/)

## License
MIT
