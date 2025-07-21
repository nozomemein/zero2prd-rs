use std::net::TcpListener;

use sqlx::PgPool;
use zero2prd_rs::{
    configuration::get_configuration,
    startup::run,
    telemetry::{get_subscriber, init_subscribe},
};

#[tokio::main]
async fn main() -> Result<(), std::io::Error> {
    let subscriber = get_subscriber("zero2prd".into(), "info".into(), std::io::stdout);
    init_subscribe(subscriber);

    let configuration = get_configuration().expect("Failed to read configuration");
    let connection_pool = PgPool::connect(&configuration.database.connection_string())
        .await
        .expect("Failed to connect to Postgres");
    let address = format!("127.0.0.1:{}", configuration.application_port);
    let listener = TcpListener::bind(address)?;
    run(listener, connection_pool)?.await
}
