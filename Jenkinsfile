pipeline {
  agent any
  stages {
    stage('install') {
      steps {
        sh  'bundle install'
      }
    }
    stage('test') {
      steps {
        sh 'bundle exec rspec'
      }
    }
  }
  environment {
    CI = 'true'
  }
}
