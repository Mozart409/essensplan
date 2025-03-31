use sqlx::{postgres::PgPoolOptions, PgPool};

pub async fn init_pool(db_url: &str) -> Result<PgPool, sqlx::Error> {
    PgPoolOptions::new()
        .acquire_timeout(std::time::Duration::from_secs(1))
        .connect(db_url)
        .await
}
