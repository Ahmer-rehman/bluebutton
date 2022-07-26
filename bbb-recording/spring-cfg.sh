#!/bin/bash
. .env

echo "Generating Spring configuration"

PERSISTENCE_DIR=./bbb-recording-api/src/main/resources
CFG_FILE=application.properties

mkdir -p ${PERSISTENCE_DIR}

#HASH=$(echo -n $POSTGRES_PASSWORD | sha256sum)
#HASH=${HASH:0:64}

CONTENT=`echo 'springfox.documentation.open-api.v3.path=/api-docs
server.servlet.contextPath=/bigbluebutton/api
server.port=8081
spring.jackson.date-format=org.bigbluebutton.RFC3339DateFormat
spring.jackson.serialization.WRITE_DATES_AS_TIMESTAMPS=false

spring.mvc.pathmatch.matching-strategy=ANT_PATH_MATCHER

spring.datasource.platform=postgres
spring.datasource.url=jdbc:postgresql://localhost:'"$HOST_PORT"'/bbb
spring.datasource.username='"$POSTGRES_USER"'
spring.datasource.password='"$POSTGRES_PASSWORD"'

spring.jpa.properties.hibernate.jdbc.lob.non_contextual_creation=true
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.PostgreSQLDialect

spring.datasource.hikari.connection.provider_class=com.zaxxer.hikari.hibernate.HikariConnectionProvider
spring.datasource.hikari.minimumIdle=5
spring.datasource.hikari.minimumPoolSize=10
spring.datasource.hikari.idelTimeout=30000

spring.flyway.enabled=false

bbb.web.defaultServerUrl=http://bigbluebutton.example.com
bbb.web.defaultTextTrackUrl=${bbb.web.defaultServerUrl}/bigbluebutton

# Required if you are using version 1 of the API
bbb.security.salt=

# Required if you are using version 2 of the API
bbb.security.api_key=

bbb.recording.publishedDir=/var/bigbluebutton/published
bbb.recording.unpublishedDir=/var/bigbluebutton/unpublished
bbb.recording.captionsDir=/var/bigbluebutton/captions
bbb.recording.presentationBaseDir=/var/bigbluebutton
'`

echo "$CONTENT" > "${PERSISTENCE_DIR}/${CFG_FILE}"

