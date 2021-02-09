pipeline {
  agent any
  stages {
    stage('install') {
      steps {
        sh 'gem install bundler -v "$(grep -A 1 "BUNDLED WITH" Gemfile.lock | tail -n 1)"'
        sh 'bundle config internal-gemserver.weinvest.net $GEMSERVER_AUTH'
        sh 'bundle install'
      }
    }
    stage('test') {
      steps {
        sh 'TIME_TRAVEL_UPDATE_MODE=native bundle exec rspec'
        sh 'TIME_TRAVEL_UPDATE_MODE=sql bundle exec rspec'
      }
    }
  }
  environment {
    CI = 'true'
  }
}
