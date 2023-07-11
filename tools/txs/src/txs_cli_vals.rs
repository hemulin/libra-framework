//! Validator subcommands

use crate::submit_transaction::Sender;
use libra_cached_packages::aptos_stdlib::EntryFunctionCall::JailUnjailByVoucher;
use zapatos_types::account_address::AccountAddress;

#[derive(clap::Subcommand)]
pub enum ValidatorTxs {
    Pof {
        #[clap(short, long)]
        /// what percent of the nominal reward you are paying to join set, with two decimal places: 12.34 becomes 12.34%
        bid_pct: f64,
        #[clap(short, long)]
        /// epoch number in which this bid expires. The validity of the bit is inclusive of the epoch number, that is, on `expiry + 1` the bid is no longer valid. If it should not expire the number must be 0.
        expiry: u64,
    },
    Jail {
        #[clap(short, long)]
        /// you are a voucher for a validator which is jailed. you are un-jailing this validator after checking that they are able to join again.
        unjail_acct: AccountAddress,
    },
    Vouch {
        #[clap(short, long)]
        /// This is an account that you are vouching for. They may not be a validator account.
        vouch_acct: AccountAddress,
        #[clap(short, long)]
        /// If you are revoking the vouch for the account specified here.
        revoke: bool,
    },
}

impl ValidatorTxs {
    pub async fn run(&self, sender: &mut Sender) -> anyhow::Result<()> {
        match self {
            ValidatorTxs::Pof { bid_pct, expiry } => {
              todo!()
            }
            ValidatorTxs::Jail { unjail_acct } => {
                let payload = JailUnjailByVoucher { addr: unjail_acct.to_owned() };
                sender.sign_submit_wait(payload.encode()).await?;
                Ok(())
            }
            ValidatorTxs::Vouch { vouch_acct, revoke } => todo!(),
        }
        // Ok(())
    }
}
