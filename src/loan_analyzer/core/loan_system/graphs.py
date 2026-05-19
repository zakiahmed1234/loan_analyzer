import pandas as pd
import plotly.graph_objects as go
import plotly.express as px
import json
import datetime

def sanitize_data(data):
    """
    Ensures data is JSON serializable by converting non-serializable types.
    Explicitly converts numpy arrays and pandas Series to lists to avoid binary encoding.
    """
    if isinstance(data, dict):
        return {k: sanitize_data(v) for k, v in data.items()}
    elif isinstance(data, (list, tuple, set)):
        return [sanitize_data(v) for v in data]
    elif hasattr(data, 'tolist'): # Handle numpy arrays and pandas Series
        return sanitize_data(data.tolist())
    elif pd.isna(data) if not isinstance(data, (list, dict, str)) else False:
        return None
    elif isinstance(data, (pd.Timestamp, datetime.date, datetime.datetime)):
        return data.isoformat()
    elif isinstance(data, (int, float, str, bool)) or data is None:
        return data
    return str(data)

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
    def vintage_dpd_trend(df):
        if df is None or df.empty: return ChartFactory._to_json(go.Figure())
        
        # Calculate DPD 30+ (Sum of 30-59, 60-89, 90+, and Write-off)
        df['dpd_30_plus'] = df['pct_30_59'] + df['pct_60_89'] + df['pct_90_plus'] + df['pct_write_off']
        
        fig = go.Figure()
        df['vintage'] = pd.to_datetime(df['vintage'])
        vintages = sorted(df['vintage'].unique(), reverse=True)
        
        for v in vintages[:5]: # Plot top 5 vintages
            v_df = df[df['vintage'] == v].sort_values('mob')
            fig.add_trace(go.Scatter(
                x=v_df['mob'], 
                y=v_df['dpd_30_plus'],
                mode='lines+markers',
                name=f'Vintage {v.strftime("%Y-%m")}'
            ))
            
        fig.update_layout(
            title='DPD 30+ Rate by Months on Book (MOB)',
            xaxis_title='Months on Book (MOB)',
            yaxis_title='DPD 30+ Rate (%)',
            hovermode='closest'
        )
        return ChartFactory._to_json(fig)
