use zapatos_sdk::rest_client::aptos::Balance;
use zapatos_sdk::rest_client::Client;
use zapatos_types::account_address::AccountAddress;
use anyhow::{anyhow, bail};

pub async fn get_libra_balance(client: &Client, address: AccountAddress) -> anyhow::Result<Balance> {
  let resp = client
      .get_account_resource(address, "0x1::coin::CoinStore<0x1::gas_coin::GasCoin>")
      .await?;
  resp.and_then(|resource| {
      if let Some(res) = resource {
          let b = serde_json::from_value::<Balance>(res.data)?;
          Ok(b)
      } else {
          bail!("No data returned");
      }
  })?
}