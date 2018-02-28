import * as React from "react";
import { connect } from "react-redux";

import InkTable from "./ink_table";

const mapStateToProps = ({ active }) => ({ entries: active });

const ActiveCollectedInks = ({entries}) => <div><InkTable entries={entries}/></div>;

export default connect(mapStateToProps)(ActiveCollectedInks);
