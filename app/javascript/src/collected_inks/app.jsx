import * as React from "react";

import ActiveCollectedInks from "./components/active_collected_inks";
import ArchivedCollectedInks from "./components/archived_collected_inks";

const App = () => <div>
  <ActiveCollectedInks />
  <ArchivedCollectedInks />
</div>;

export default App;
