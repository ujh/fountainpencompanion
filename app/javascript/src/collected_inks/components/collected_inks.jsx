import * as React from "react";

import ActiveCollectedInks from "./active_collected_inks";
import ArchivedCollectedInks from "./archived_collected_inks";

const CollectedInks = () => <div>
  <ActiveCollectedInks />
  <ArchivedCollectedInks />
</div>;

export default CollectedInks;
