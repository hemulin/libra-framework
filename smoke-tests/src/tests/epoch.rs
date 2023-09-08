use diem_forge::Swarm;

use crate::{libra_smoke::LibraSmoke, helpers};

/// testing epoch changes after 2 mins
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn meta_epoch_change() -> anyhow::Result<()> {
    let mut s = LibraSmoke::new(None)
        .await
        .expect("cannot start libra swarm");
    let mut p = s.swarm.diem_public_info();
    let prev_epoch = {
        let client = p.client();
        let li = client.get_ledger_information().await?;
        li.inner().epoch
    };

    // dbg!(&p.root_account());

    // let state = p.reconfig().await;
    let fast_forward_seconds = 3 * 60;
    helpers::trigger_epoch_boundary(&mut p, fast_forward_seconds).await?;
    // epoch_boundary::epoch_boundary vm, epoch

    let epoch = {
        let client = p.client();
        let li = client.get_ledger_information().await?;
        li.inner().epoch
    };
    assert!(prev_epoch < epoch, "epoch did not advance on reconfig()");

    Ok(())
}
