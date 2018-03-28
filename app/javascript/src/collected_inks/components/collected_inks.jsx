import * as React from "react";

import ActiveCollectedInks from "./active_collected_inks";
import ArchivedCollectedInks from "./archived_collected_inks";
import Export from "./export";

const CollectedInks = () => <div>
  <Export />
  <ActiveCollectedInks />
  <ArchivedCollectedInks />
</div>;

export default CollectedInks;
