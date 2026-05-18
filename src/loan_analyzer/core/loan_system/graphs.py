class ChartFactory:
    @staticmethod
    def _to_json(fig):
        fig.update_layout(
            template="plotly_white",
            margin=dict(t=50, b=20, l=20, r=20),
            autosize=True,
            hovermode='x unified'
        )
        # fig.to_dict() is safe and fast
        return sanitize_data(fig.to_dict())

    @staticmethod
    def score_prog(df):
        if df is None or df.empty: return ChartFactory._to_json(go.Figure())
        df['origination_month'] = pd.to_datetime(df['origination_month'])
        df = df.sort_values('origination_month')
        ext = pd.to_numeric(df['avg_external_score'], errors='coerce').fillna(0)
        int_ = pd.to_numeric(df['avg_internal_score'], errors='coerce').fillna(0)
        df['ext_z'] = (ext - ext.mean()) / ext.std() if ext.std() != 0 else 0
        df['int_z'] = (int_ - int_.mean()) / int_.std() if int_.std() != 0 else 0
        fig = go.Figure()
        x_axis = df['origination_month'].dt.strftime('%Y-%m').tolist()
        fig.add_trace(go.Scatter(x=x_axis, y=df['ext_z'].tolist(), mode='lines+markers', name='External (z)'))
        fig.add_trace(go.Scatter(x=x_axis, y=df['int_z'].tolist(), mode='lines+markers', name='Internal (z)'))
        fig.update_layout(title='Standardised Score Trends')
        return ChartFactory._to_json(fig)

    @staticmethod
    def status_distribution(df):
        if df is None or df.empty: return ChartFactory._to_json(go.Figure())
        df['mob'] = pd.to_numeric(df['mob'], errors='coerce')
        counts = df.groupby(['mob', 'status_at_mob']).size().reset_index(name='count')
        total = counts.groupby('mob')['count'].transform('sum')
        counts['pct'] = (counts['count'] / total) * 100
        fig = px.area(counts, x='mob', y='pct', color='status_at_mob', title="Status Distribution (%)")
        return ChartFactory._to_json(fig)

    @staticmethod
    def instalment_delinquency(df):
        if df is None or df.empty: return ChartFactory._to_json(go.Figure())
        df = df.sort_values('scheduled_instalment_date')
        df['cum_dpd'] = (df['dpd_category'] == 'dpd 90+').astype(int).cumsum()
        fig = go.Figure(go.Scatter(x=pd.to_datetime(df['scheduled_instalment_date']).dt.strftime('%Y-%m-%d').tolist(), y=df['cum_dpd'].tolist(), fill='tozeroy', line_color='red'))
        fig.update_layout(title="Cumulative Defaults (90+ DPD)")
        return ChartFactory._to_json(fig)

    @staticmethod
    def defaults(df):
        if df is None or df.empty: return ChartFactory._to_json(go.Figure())
        df['vintage'] = pd.to_datetime(df['vintage'])
        counts = df.groupby('vintage')['loan_id'].count().reset_index().sort_values('vintage')
        fig = go.Figure(go.Bar(x=counts['vintage'].dt.strftime('%Y-%m').tolist(), y=counts['loan_id'].tolist(), marker_color='red'))
        fig.update_layout(title='Defaults per Vintage')
        return ChartFactory._to_json(fig)

    @staticmethod
    def grade_dist(df):
        if df is None or df.empty: return ChartFactory._to_json(go.Figure())
        df['origination_month'] = pd.to_datetime(df['origination_month'])
        pivot = df.pivot(index='origination_month', columns='loan_grade', values='pct_of_monthly_count').fillna(0)
        fig = go.Figure()
        for g in [col for col in ['A','B','C'] if col in pivot.columns]:
            fig.add_trace(go.Scatter(x=pivot.index.strftime('%Y-%m').tolist(), y=pivot[g].tolist(), stackgroup='one', name=f'Grade {g}'))
        fig.update_layout(title='Grade Mix Over Time')
        return ChartFactory._to_json(fig)

    @staticmethod
    def credit_profiles(df):
        if df is None or df.empty: return ChartFactory._to_json(go.Figure())
        df = df[df['loan_sequence_number'] > 1]
        if df.empty: return ChartFactory._to_json(go.Figure())
        agg = df.groupby('loan_sequence_number')[['bureau_score_delta', 'internal_score_delta']].mean().reset_index()
        fig = go.Figure()
        fig.add_trace(go.Scatter(x=agg['loan_sequence_number'].tolist(), y=agg['bureau_score_delta'].tolist(), name='Bureau Δ'))
        fig.add_trace(go.Scatter(x=agg['loan_sequence_number'].tolist(), y=agg['internal_score_delta'].tolist(), name='Internal Δ'))
        fig.add_shape(type="line", x0=agg['loan_sequence_number'].min(), x1=agg['loan_sequence_number'].max(), y0=0, y1=0, line=dict(dash="dash"))
        fig.update_layout(title='Avg Score Change by Loan Sequence')
        return ChartFactory._to_json(fig)

    @staticmethod
    def unique_borrower_delta(df):
        if df is None or df.empty: return ChartFactory._to_json(go.Figure())
        df = df.sort_values('signup_month')
        x = pd.to_datetime(df['signup_month']).dt.strftime('%Y-%m').tolist()
        fig = go.Figure()
        fig.add_trace(go.Bar(x=x, y=df['new_borrowers_this_month'].tolist(), name='New', yaxis='y1'))
        fig.add_trace(go.Scatter(x=x, y=df['total_borrowers_to_date'].tolist(), name='Total', yaxis='y2'))
        fig.update_layout(title='Borrower Growth', yaxis=dict(title='Monthly New'), yaxis2=dict(title='Total', overlaying='y', side='right'))
        return ChartFactory._to_json(fig)

    @staticmethod
    def loan_interval(df):
        if df is None or df.empty: return ChartFactory._to_json(go.Figure())
        y_vals = pd.to_numeric(df[df['total_repeat_loans'] > 1]['avg_days_between_loans'], errors='coerce').dropna().tolist()
        fig = go.Figure(go.Histogram(x=y_vals, nbinsx=15, marker_color='#1abc9c'))
        fig.update_layout(title='Days Between Repeat Loans')
        return ChartFactory._to_json(fig)

    @staticmethod
    def location_monthly(df):
        if df is None or df.empty: return ChartFactory._to_json(go.Figure())
        pivot = df.pivot_table(index='approval_month', columns='location_state_province', values='total_amount_approved', aggfunc='sum', fill_value=0)
        fig = go.Figure()
        for loc in pivot.columns:
            fig.add_trace(go.Scatter(x=pd.to_datetime(pivot.index).strftime('%Y-%m').tolist(), y=pivot[loc].tolist(), name=loc))
        fig.update_layout(title='Regional Volume')
        return ChartFactory._to_json(fig)

    @staticmethod
    def loan_use_monthly(df):
        if df is None or df.empty: return ChartFactory._to_json(go.Figure())
        pivot = df.pivot(index='disbursement_month', columns='loan_use', values='monthly_amount').fillna(0)
        fig = go.Figure()
        for use in pivot.columns:
            fig.add_trace(go.Scatter(x=pd.to_datetime(pivot.index).strftime('%Y-%m').tolist(), y=pivot[use].tolist(), name=use))
        fig.update_layout(title='Volume by Loan Use')
        return ChartFactory._to_json(fig)

    @staticmethod
    def fee_per_amount_over_time(df):
        if df is None or df.empty: return ChartFactory._to_json(go.Figure())
        df = df.sort_values('origination_month')
        fig = go.Figure(go.Scatter(x=pd.to_datetime(df['origination_month']).dt.strftime('%Y-%m-%d').tolist(), y=df['fee_yield_ratio_pct'].tolist(), mode='lines+markers', marker_color='#2ecc71'))
        fig.update_layout(title='Fee Yield Ratio Over Time')
        return ChartFactory._to_json(fig)

    @staticmethod
    def pricing_over_risk(df):
        if df is None or df.empty: return ChartFactory._to_json(go.Figure())
        df['origination_month'] = pd.to_datetime(df['origination_month'])
        df_pivot = df.pivot(index='origination_month', columns='loan_grade', values='pct_of_monthly_volume').fillna(0)
        fig = go.Figure()
        for grade in ['A', 'B', 'C']:
            if grade in df_pivot.columns:
                fig.add_trace(go.Scatter(x=df_pivot.index.strftime('%Y-%m').tolist(), y=df_pivot[grade].tolist(), mode='lines+markers', name=f'Grade {grade}'))
        fig.update_layout(title='Monthly Volume % by Grade')
        return ChartFactory._to_json(fig)

    @staticmethod
    def yield_curve_evolution(df):
        if df is None or df.empty: return ChartFactory._to_json(go.Figure())
        df['origination_vintage'] = pd.to_datetime(df['origination_vintage'])
        df['maturity_month'] = pd.to_datetime(df['maturity_month'])
        selected = sorted(df['origination_vintage'].unique(), reverse=True)[:3]
        fig = go.Figure()
        for v in selected:
            v_df = df[df['origination_vintage'] == v].sort_values('maturity_month')
            fig.add_trace(go.Scatter(x=v_df['maturity_month'].dt.strftime('%Y-%m').tolist(), y=v_df['weighted_avg_yield'].tolist(), mode='lines+markers', name=f'Vintage {v.strftime("%Y-%m")}'))
        fig.update_layout(title='Yield Curve (Top 3 Vintages)')
        return ChartFactory._to_json(fig)

